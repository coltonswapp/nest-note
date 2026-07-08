import CryptoKit
import Foundation
import UIKit

extension Notification.Name {
    static let sessionPDFDidUpdate = Notification.Name("sessionPDFDidUpdate")
}

enum SessionPDFServiceError: Error {
    case noNest
    case generationFailed
}

final class SessionPDFService {
    static let shared = SessionPDFService()

    private let fileManager = FileManager.default
    private var regeneratingSessionIDs: Set<String> = []
    private let regeneratingLock = NSLock()

    private init() {}

    // MARK: - Local Storage

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SessionPDFs", isDirectory: true)
    }

    func localPDFURL(nestID: String, sessionID: String) -> URL {
        baseDirectory
            .appendingPathComponent(nestID, isDirectory: true)
            .appendingPathComponent("\(sessionID).pdf")
    }

    func localPDFFileExists(nestID: String, sessionID: String) -> Bool {
        fileManager.fileExists(atPath: localPDFURL(nestID: nestID, sessionID: sessionID).path)
    }

    // MARK: - Content Hash

    func contentHash(session: SessionItem, events: [SessionEvent], selectedItemIds: [String]) -> String {
        var components: [String] = []
        components.append(session.title)
        components.append(String(session.startDate.timeIntervalSince1970))
        components.append(String(session.endDate.timeIntervalSince1970))
        components.append(String(session.isMultiDay))

        components.append(selectedItemIds.sorted().joined(separator: ","))

        let sortedEvents = events.sorted { $0.id < $1.id }
        for event in sortedEvents {
            components.append(event.id)
            components.append(event.title)
            components.append(String(event.startDate.timeIntervalSince1970))
            components.append(String(event.endDate.timeIntervalSince1970))
            components.append(event.placeID ?? "")
        }

        let inputData = Data(components.joined(separator: "|").utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    func isCachedPDFValid(for session: SessionItem, events: [SessionEvent], selectedItemIds: [String]) -> Bool {
        guard let storedHash = session.pdfContentHash else { return false }
        guard localPDFFileExists(nestID: session.nestID, sessionID: session.id) else { return false }
        let currentHash = contentHash(session: session, events: events, selectedItemIds: selectedItemIds)
        return storedHash == currentHash
    }

    func isRegenerating(sessionID: String) -> Bool {
        regeneratingLock.lock()
        defer { regeneratingLock.unlock() }
        return regeneratingSessionIDs.contains(sessionID)
    }

    // MARK: - Generate & Cache

    func generateAndCache(
        session: SessionItem,
        events: [SessionEvent],
        selectedItemIds: [String]
    ) async throws -> URL {
        guard let nest = NestService.shared.currentNest else {
            throw SessionPDFServiceError.noNest
        }

        let resolvedItemIds = selectedItemIds.isEmpty ? (session.entryIds ?? []) : selectedItemIds

        guard let pdfData = await PDFExportService.generateSessionPDF(
            session: session,
            nestItem: nest,
            events: events,
            selectedItemIds: resolvedItemIds
        ) else {
            throw SessionPDFServiceError.generationFailed
        }

        let url = localPDFURL(nestID: session.nestID, sessionID: session.id)
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try pdfData.write(to: url, options: .atomic)

        let hash = contentHash(session: session, events: events, selectedItemIds: resolvedItemIds)
        try await updateSessionMetadata(session: session, hash: hash)

        return url
    }

    func updateSessionMetadata(session: SessionItem, hash: String) async throws {
        session.pdfGeneratedAt = Date()
        session.pdfContentHash = hash
        try await SessionService.shared.updateSession(session)

        NotificationCenter.default.post(
            name: .sessionPDFDidUpdate,
            object: nil,
            userInfo: ["sessionId": session.id]
        )
    }

    func removeLocalPDFFile(nestID: String, sessionID: String) {
        let url = localPDFURL(nestID: nestID, sessionID: sessionID)
        try? fileManager.removeItem(at: url)
    }

    func deleteCachedPDF(for session: SessionItem) async throws {
        removeLocalPDFFile(nestID: session.nestID, sessionID: session.id)
        session.pdfGeneratedAt = nil
        session.pdfContentHash = nil
        try await SessionService.shared.updateSession(session)

        NotificationCenter.default.post(
            name: .sessionPDFDidUpdate,
            object: nil,
            userInfo: ["sessionId": session.id]
        )
    }

    func regenerateIfNeededAfterSave(
        session: SessionItem,
        events: [SessionEvent],
        selectedItemIds: [String]
    ) {
        let resolvedItemIds = selectedItemIds.isEmpty ? (session.entryIds ?? []) : selectedItemIds
        let newHash = contentHash(session: session, events: events, selectedItemIds: resolvedItemIds)

        guard session.pdfContentHash != nil else { return }
        guard newHash != session.pdfContentHash else { return }

        Task {
            guard await SubscriptionService.shared.canUseFullFeatures() else { return }

            beginRegenerating(sessionID: session.id)

            do {
                _ = try await generateAndCache(
                    session: session,
                    events: events,
                    selectedItemIds: resolvedItemIds
                )
            } catch {
                Logger.log(
                    level: .error,
                    category: .sessionService,
                    message: "Failed to auto-regenerate session PDF: \(error.localizedDescription)"
                )
            }

            endRegenerating(sessionID: session.id)
        }
    }

    private func beginRegenerating(sessionID: String) {
        regeneratingLock.lock()
        regeneratingSessionIDs.insert(sessionID)
        regeneratingLock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .sessionPDFDidUpdate,
                object: nil,
                userInfo: ["sessionId": sessionID, "isRegenerating": true]
            )
        }
    }

    private func endRegenerating(sessionID: String) {
        regeneratingLock.lock()
        regeneratingSessionIDs.remove(sessionID)
        regeneratingLock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .sessionPDFDidUpdate,
                object: nil,
                userInfo: ["sessionId": sessionID, "isRegenerating": false]
            )
        }
    }
}
