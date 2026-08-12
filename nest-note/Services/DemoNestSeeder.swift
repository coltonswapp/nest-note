//
//  DemoNestSeeder.swift
//  nest-note
//
//  DEBUG-only: creates the shared demo nest and publishes catalog content + sample sessions.
//

#if DEBUG
import Foundation
import FirebaseFirestore

enum DemoNestSeeder {
    private static let db = Firestore.firestore()

    static func createDemoNestIfNeeded() async throws -> String {
        await DemoModeService.shared.refreshConfig()
        if let existing = DemoModeService.shared.nestId {
            return existing
        }

        guard let ownerId = UserService.shared.currentUser?.id else {
            throw DemoModeError.notSignedIn
        }

        let previousNest = NestService.shared.currentNest
        let nest = try await NestService.shared.createNest(
            ownerId: ownerId,
            name: DemoNestSeed.nestName,
            address: DemoNestSeed.nestAddress,
            careResponsibilities: DemoNestSeed.folders.map(\.name)
        )

        if let previousNest {
            NestService.shared.setCurrentNest(previousNest)
        }

        try await DemoModeService.shared.writeConfig(nestId: nest.id, enabled: true)
        Logger.log(level: .info, category: .demoMode, message: "Created demo nest \(nest.id)")
        return nest.id
    }

    static func publishContent() async throws {
        let nestId = try await createDemoNestIfNeeded()
        try await replaceContent(on: nestId)
        NestService.shared.purgeCachesAfterExternalMutation()
        if NestService.shared.currentNest?.id == nestId {
            try await LaunchCoordinator.shared?.reloadInterface()
        }
        Logger.log(level: .info, category: .demoMode, message: "Published demo content to \(nestId)")
    }

    private static func replaceContent(on nestId: String) async throws {
        try await deleteCollection(db.collection("nests").document(nestId).collection("entries"))
        try await deleteCollection(db.collection("nests").document(nestId).collection("nestCategories"))
        try await deleteSessions(on: nestId)

        let repository = FirebaseItemRepository(nestId: nestId)
        var createdItemIds: [String] = []

        for folder in DemoNestSeed.folders {
            let category = NestCategory(
                name: folder.name,
                symbolName: folder.symbolName,
                isDefault: true,
                isPinned: folder.isPinned
            )
            let categoryRef = db.collection("nests").document(nestId).collection("nestCategories").document(category.id)
            try await categoryRef.setData(try Firestore.Encoder().encode(category))

            for spec in folder.items {
                let itemId = try await createItem(spec, category: folder.name, nestId: nestId, repository: repository)
                createdItemIds.append(itemId)
            }
        }

        let pinned = DemoNestSeed.folders.filter(\.isPinned).map(\.name)
        try await db.collection("nests").document(nestId).setData([
            "name": DemoNestSeed.nestName,
            "address": DemoNestSeed.nestAddress,
            "pinnedCategories": pinned
        ], merge: true)

        try await createSampleSessions(nestId: nestId, itemIds: createdItemIds)
    }

    private static func createItem(
        _ spec: DemoNestSeed.ItemSpec,
        category: String,
        nestId: String,
        repository: FirebaseItemRepository
    ) async throws -> String {
        switch spec {
        case .note(let title, let content):
            let note = NoteItem(title: title, content: content, category: category)
            try await repository.createItem(note)
            return note.id
        case .routine(let title, let actions):
            let routine = RoutineItem(title: title, category: category, routineActions: actions)
            try await repository.createItem(routine)
            return routine.id
        case .place(let title, let address, let coordinate, _, _):
            let place = PlaceItem(
                nestId: nestId,
                category: category,
                alias: title,
                address: address,
                coordinate: coordinate,
                isTemporary: false
            )
            try await repository.createItem(place)
            return place.id
        }
    }

    private static func createSampleSessions(nestId: String, itemIds: [String]) async throws {
        guard let ownerID = UserService.shared.currentUser?.id else { return }

        let calendar = Calendar.current
        let now = Date()
        let sharedIds = Array(itemIds.prefix(8))

        let inProgressStart = calendar.date(byAdding: .hour, value: -2, to: now) ?? now
        let inProgressEnd = calendar.date(byAdding: .hour, value: 3, to: now) ?? now
        let upcomingStart = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let upcomingEnd = calendar.date(byAdding: .hour, value: 4, to: upcomingStart) ?? upcomingStart
        let completedStart = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        let completedEnd = calendar.date(byAdding: .hour, value: 4, to: completedStart) ?? completedStart

        let sessions = [
            SessionItem(
                title: "Friday night",
                startDate: inProgressStart,
                endDate: inProgressEnd,
                status: .inProgress,
                nestID: nestId,
                ownerID: ownerID,
                entryIds: sharedIds
            ),
            SessionItem(
                title: "Saturday afternoon",
                startDate: upcomingStart,
                endDate: upcomingEnd,
                status: .upcoming,
                nestID: nestId,
                ownerID: ownerID,
                entryIds: Array(itemIds.prefix(5))
            ),
            SessionItem(
                title: "Tuesday evening",
                startDate: completedStart,
                endDate: completedEnd,
                status: .completed,
                nestID: nestId,
                ownerID: ownerID,
                entryIds: Array(itemIds.prefix(6))
            )
        ]

        let sessionsRef = db.collection("nests").document(nestId).collection("sessions")
        for session in sessions {
            try sessionsRef.document(session.id).setData(from: session)
        }
    }

    private static func deleteSessions(on nestId: String) async throws {
        let sessionsRef = db.collection("nests").document(nestId).collection("sessions")
        let snapshot = try await sessionsRef.getDocuments()
        for document in snapshot.documents {
            try await deleteCollection(document.reference.collection("events"))
            try await document.reference.delete()
        }
    }

    private static func deleteCollection(_ collection: CollectionReference) async throws {
        let snapshot = try await collection.getDocuments()
        guard !snapshot.documents.isEmpty else { return }
        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
    }
}
#endif
