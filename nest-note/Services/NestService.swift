//
//  NestService.swift
//  nest-note
//
//  Created by Colton Swapp on 1/19/25

import Foundation
import FirebaseFirestore

final class NestService {
    
    // MARK: - Properties
    static let shared = NestService()
    private let db = Firestore.firestore()
    
    @Published private(set) var currentNest: NestItem?
    
    // Add cached entries
    private var cachedEntries: [String: [BaseEntry]]?
    
    // MARK: - Initialization
    private init() {}

     // MARK: - Setup
    func setup() async throws {
        guard let currentUser = UserService.shared.currentUser else {
            Logger.log(level: .info, category: .nestService, message: "No current user, skipping nest setup")
            return
        }
        
        // Only setup nest if user is an owner
        guard currentUser.primaryRole == .nestOwner else {
            Logger.log(level: .info, category: .nestService, message: "User is not an owner, skipping nest setup")
            return
        }
        
        // Find first nest where user is the owner
        guard let primaryNestId = currentUser.roles.nestAccess.first(where: { $0.accessLevel == .owner })?.nestId else {
            Logger.log(level: .info, category: .nestService, message: "Owner has no owned nests")
            return
        }
        
        try await fetchAndSetCurrentNest(nestId: primaryNestId)
        Logger.log(level: .info, category: .nestService, message: currentNest != nil ? "Nest setup complete with nest: \(currentNest!)": "Nest setup incomplete.. (no nest found) ❌")
    }
    
    func reset() async {
        Logger.log(level: .info, category: .nestService, message: "Resetting NestService...")
        currentNest = nil
        clearEntriesCache()
    }
    
    // MARK: - Current Nest Methods
    func setCurrentNest(_ nest: NestItem) {
        Logger.log(level: .info, category: .nestService, message: "Setting current nest to: \(nest.name)")
        self.currentNest = nest
    }
    
    func fetchAndSetCurrentNest(nestId: String) async throws {
        Logger.log(level: .info, category: .nestService, message: "Fetching nest: \(nestId)")
        
        let docRef = db.collection("nests").document(nestId)
        let document = try await docRef.getDocument()
        
        guard let nest = try? document.data(as: NestItem.self) else {
            throw NestError.nestNotFound
        }
        
        Logger.log(level: .info, category: .nestService, message: "Nest fetched successfully ✅")
        setCurrentNest(nest)
    }
    
    // MARK: - Firestore Methods
    func createNest(ownerId: String, name: String, address: String) async throws -> NestItem {
        Logger.log(level: .info, category: .nestService, message: "Creating new nest for user: \(ownerId)")
        
        let nest = NestItem(
            ownerId: ownerId,
            name: name,
            address: address
        )
        
        let docRef = db.collection("nests").document(nest.id)
        try await docRef.setData(try Firestore.Encoder().encode(nest))
        
        // Create default categories first
        try await createDefaultCategories(for: nest.id)
        
        // Then create default entries
        try await createDefaultEntries(for: nest.id)
        
        Logger.log(level: .info, category: .nestService, message: "Nest created successfully with default categories and entries ✅")
        
        // Set as current nest after creation
        setCurrentNest(nest)
        return nest
    }
    
    // MARK: - Entry Methods
    func createEntry(_ entry: BaseEntry) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let docRef = db.collection("nests").document(nestId).collection("entries").document(entry.id)
        try await docRef.setData(try Firestore.Encoder().encode(entry))
        
        // Add entry to currentNest.entries
        if var updatedNest = currentNest {
            if updatedNest.entries == nil {
                updatedNest.entries = []
            }
            updatedNest.entries?.append(entry)
            currentNest = updatedNest
        }
        
        Logger.log(level: .info, category: .nestService, message: "Entry created successfully: \(entry.title)")
    }
    
    func updateEntry(_ entry: BaseEntry) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let docRef = db.collection("nests").document(nestId).collection("entries").document(entry.id)
        try await docRef.setData(try Firestore.Encoder().encode(entry))
        
        // Update entry in currentNest.entries
        if var updatedNest = currentNest {
            if let index = updatedNest.entries?.firstIndex(where: { $0.id == entry.id }) {
                updatedNest.entries?[index] = entry
                Logger.log(level: .info, category: .nestService, message: "Updated entry in cache: \(entry.title)")
            }
            currentNest = updatedNest
        }
        
        Logger.log(level: .info, category: .nestService, message: "Entry updated successfully in Firestore: \(entry.title)")
    }
    
    func fetchEntries() async throws -> [String: [BaseEntry]] {
        // Return cached entries if available
        if let cachedEntries = cachedEntries {
            Logger.log(level: .info, category: .nestService, message: "Using cached entries")
            return cachedEntries
        }
        
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        // Fetch categories first
        let categories = try await fetchCategories()
        let categoryNames = Set(categories.map { $0.name })
        
        let snapshot = try await db.collection("nests").document(nestId).collection("entries").getDocuments()
        var entries = try snapshot.documents.map { try $0.data(as: BaseEntry.self) }
        
        // Move entries with non-existent categories to "Other"
        for (index, entry) in entries.enumerated() {
            if !categoryNames.contains(entry.category) {
                entries[index].category = "Other"
            }
        }
        
        // Group entries by category
        let groupedEntries = Dictionary(grouping: entries) { $0.category }
        Logger.log(level: .info, category: .nestService, message: "Fetched \(entries.count) entries from Firestore")
        
        // Cache the entries
        self.cachedEntries = groupedEntries
        
        return groupedEntries
    }
    
    // Add method to clear cache
    func clearEntriesCache() {
        Logger.log(level: .info, category: .nestService, message: "Clearing entries cache")
        cachedEntries = nil
    }
    
    // Add this method for when we need to force a refresh
    func refreshEntries() async throws -> [String: [BaseEntry]] {
        clearEntriesCache()
        return try await fetchEntries()
    }
    
    // Creates default entries for a new nest
    func createDefaultEntries(for nestId: String) async throws {
        for entry in Self.defaultEntries {
            let docRef = db.collection("nests").document(nestId).collection("entries").document(entry.id)
            try await docRef.setData(try Firestore.Encoder().encode(entry))
        }
        Logger.log(level: .info, category: .nestService, message: "Created \(Self.defaultEntries.count) default entries")
    }
    
    // Add to NestService class
    func deleteEntry(_ entry: BaseEntry) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let docRef = db.collection("nests").document(nestId).collection("entries").document(entry.id)
        do {
            try await docRef.delete()
            
            // Update cache if it exists
            if var groupedEntries = cachedEntries {
                groupedEntries[entry.category]?.removeAll { $0.id == entry.id }
                cachedEntries = groupedEntries
            }
            
            Logger.log(level: .info, category: .nestService, message: "Entry deleted successfully: \(entry.title)")
        } catch {
            throw error
        }
    }
}

// MARK: - Errors
extension NestService {
    enum NestError: LocalizedError {
        case nestNotFound
        case noCurrentNest
        
        var errorDescription: String? {
            switch self {
            case .nestNotFound:
                return "The requested nest could not be found"
            case .noCurrentNest:
                return "No nest is currently selected"
            }
        }
    }
}

// MARK: - Default Entries
extension NestService {
    static let defaultEntries: [BaseEntry] = [
        // Household
        BaseEntry(title: "Garage Code", content: "--", visibilityLevel: .essential, category: "Household"),
        BaseEntry(title: "Alarm Code", content: "--", visibilityLevel: .essential, category: "Household"),
        BaseEntry(title: "WiFi Setup", content: "--", visibilityLevel: .essential, category: "Household"),
        BaseEntry(title: "Appliance Guide", content: "--", visibilityLevel: .standard, category: "Household"),
        BaseEntry(title: "Trash Schedule", content: "--", visibilityLevel: .standard, category: "Household"),
        
        // Emergency
        BaseEntry(title: "Medical Info", content: "--", visibilityLevel: .essential, category: "Emergency"),
        BaseEntry(title: "First Aid Location", content: "--", visibilityLevel: .essential, category: "Emergency"),
        BaseEntry(title: "Emergency Shutoffs", content: "--", visibilityLevel: .essential, category: "Emergency"),
        BaseEntry(title: "Nearest Hospital", content: "--", visibilityLevel: .essential, category: "Emergency"),
        
        // Rules & Guidelines
        BaseEntry(title: "House Rules", content: "--", visibilityLevel: .essential, category: "Rules & Guidelines"),
        BaseEntry(title: "Screen Time", content: "--", visibilityLevel: .essential, category: "Rules & Guidelines"),
        BaseEntry(title: "Approved Media", content: "--", visibilityLevel: .standard, category: "Rules & Guidelines"),
        BaseEntry(title: "Food Rules", content: "--", visibilityLevel: .essential, category: "Rules & Guidelines"),
        BaseEntry(title: "Off-Limits Areas", content: "--", visibilityLevel: .essential, category: "Rules & Guidelines"),
        
        // Pets
        BaseEntry(title: "Schedule", content: "--", visibilityLevel: .essential, category: "Pets"),
        BaseEntry(title: "Vet Info", content: "--", visibilityLevel: .standard, category: "Pets"),
        BaseEntry(title: "Behavior", content: "--", visibilityLevel: .essential, category: "Pets"),
        BaseEntry(title: "Medications", content: "--", visibilityLevel: .essential, category: "Pets"),
        BaseEntry(title: "Exercise Routine", content: "--", visibilityLevel: .standard, category: "Pets"),
        
        // School & Education
        BaseEntry(title: "School Details", content: "--", visibilityLevel: .standard, category: "School & Education"),
        BaseEntry(title: "Transportation", content: "--", visibilityLevel: .standard, category: "School & Education"),
        BaseEntry(title: "Homework Rules", content: "--", visibilityLevel: .standard, category: "School & Education"),
        
        // Social & Interpersonal
        BaseEntry(title: "Approved Friends", content: "--", visibilityLevel: .standard, category: "Social & Interpersonal"),
        BaseEntry(title: "Playdate Contacts", content: "--", visibilityLevel: .extended, category: "Social & Interpersonal"),
        BaseEntry(title: "Behavior Guide", content: "--", visibilityLevel: .standard, category: "Social & Interpersonal"),
        BaseEntry(title: "Comfort Routines", content: "--", visibilityLevel: .standard, category: "Social & Interpersonal"),
        BaseEntry(title: "Cultural Notes", content: "--", visibilityLevel: .standard, category: "Social & Interpersonal")
    ]
}

// MARK: - Default Categories
extension NestService {
    static let defaultCategories: [NestCategory] = [
        NestCategory(name: "Household", symbolName: "house.fill", isDefault: true, isPinned: true),
        NestCategory(name: "Emergency", symbolName: "exclamationmark.triangle.fill", isDefault: true, isPinned: true),
        NestCategory(name: "Rules & Guidelines", symbolName: "list.bullet", isDefault: true),
        NestCategory(name: "Pets", symbolName: "pawprint.fill", isDefault: true),
        NestCategory(name: "School & Education", symbolName: "book.fill", isDefault: true),
        NestCategory(name: "Social & Interpersonal", symbolName: "person.2.fill", isDefault: true),
        NestCategory(name: "Other", symbolName: "folder.fill", isDefault: true)
    ]
}

// Add these methods to the NestService class
extension NestService {
    func createDefaultCategories(for nestId: String) async throws {
        let categoriesRef = db.collection("nests").document(nestId).collection("nestCategories")
        
        for category in Self.defaultCategories {
            try await categoriesRef.document(category.id).setData(try Firestore.Encoder().encode(category))
        }
        
        Logger.log(level: .info, category: .nestService, message: "Created \(Self.defaultCategories.count) default categories")
    }
    
    func createCategory(_ category: NestCategory) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let docRef = db.collection("nests").document(nestId).collection("nestCategories").document(category.id)
        try await docRef.setData(try Firestore.Encoder().encode(category))
        
        // Update current nest's categories
        if var updatedNest = currentNest {
            if updatedNest.categories == nil {
                updatedNest.categories = []
            }
            updatedNest.categories?.append(category)
            currentNest = updatedNest
        }
        
        Logger.log(level: .info, category: .nestService, message: "Category created successfully: \(category.name)")
    }
    
    // Add method to fetch categories
    func fetchCategories() async throws -> [NestCategory] {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let snapshot = try await db.collection("nests").document(nestId).collection("nestCategories").getDocuments()
        let categories = try snapshot.documents.map { try $0.data(as: NestCategory.self) }
        
        // Update current nest's categories
        if var updatedNest = currentNest {
            updatedNest.categories = categories
            currentNest = updatedNest
        }
        
        return categories
    }
} 
