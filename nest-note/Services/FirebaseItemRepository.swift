//
//  FirebaseItemRepository.swift
//  nest-note
//
//  Created by Claude on 1/30/25.
//

import Foundation
import FirebaseFirestore

final class FirebaseItemRepository: ItemRepository {
    private let db = Firestore.firestore()
    private let collectionName = "entries"
    private let nestId: String
    
    // Cache for items - following NestService caching pattern
    private var cachedItems: [BaseItem]?
    
    init(nestId: String) {
        self.nestId = nestId
        Logger.log(level: .info, category: .firebaseItemRepo, message: "FirebaseItemRepository initialized for nest: \(nestId)")
    }
    
    // MARK: - ItemRepository Implementation
    
    func fetchItems() async throws -> [BaseItem] {
        Logger.log(level: .info, category: .firebaseItemRepo, message: "fetchItems() called")
        
        // Check cache first - following guiding principles
        if let cachedItems = cachedItems {
            Logger.log(level: .info, category: .firebaseItemRepo, message: "Returning \(cachedItems.count) items from cache")
            return cachedItems
        }
        
        Logger.log(level: .info, category: .firebaseItemRepo, message: "Cache miss - fetching items from Firestore")
        
        Logger.log(level: .debug, category: .firebaseItemRepo, message: "Fetching from collection: \(collectionName)")
        let snapshot = try await db.collection("nests").document(nestId).collection(collectionName).getDocuments()
        let items = try snapshot.documents.compactMap { document -> BaseItem? in
            return try decodeItem(from: document)
        }
        
        // Cache the results
        self.cachedItems = items
        
        Logger.log(level: .info, category: .firebaseItemRepo, message: "Fetched and cached \(items.count) items from Firestore")
        return items
    }
    
    func fetchItem(id: String) async throws -> BaseItem? {
        Logger.log(level: .info, category: .firebaseItemRepo, message: "fetchItem() called for id: \(id)")
        
        // Check cache first
        if let cachedItems = cachedItems,
           let cachedItem = cachedItems.first(where: { $0.id == id }) {
            Logger.log(level: .info, category: .firebaseItemRepo, message: "Found item \(id) in cache")
            return cachedItem
        }
        
        Logger.log(level: .info, category: .firebaseItemRepo, message: "Item \(id) not in cache - fetching from Firestore")
        
        let document = try await db.collection("nests").document(nestId).collection(collectionName).document(id).getDocument()
        
        guard document.exists else {
            Logger.log(level: .info, category: .firebaseItemRepo, message: "Item \(id) not found in Firestore")
            return nil
        }
        
        let item = try decodeItem(from: document)
        
        // Update cache if it exists
        if var items = cachedItems {
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = item
            } else {
                items.append(item)
            }
            cachedItems = items
            Logger.log(level: .info, category: .firebaseItemRepo, message: "Updated cache with fetched item \(id)")
        }
        
        return item
    }
    
    func createItem<T: BaseItem>(_ item: T) async throws {
        Logger.log(level: .info, category: .firebaseItemRepo, message: "createItem() called for item: \(item.id) of type: \(item.type.rawValue)")
        
        do {
            let docRef = db.collection("nests").document(nestId).collection(collectionName).document(item.id)
            try await docRef.setData(try Firestore.Encoder().encode(item))
            
            // Update cache - following smart cache update principles
            if var items = cachedItems {
                items.append(item)
                cachedItems = items
                Logger.log(level: .info, category: .firebaseItemRepo, message: "Added item \(item.id) to cache")
            }
            
            Logger.log(level: .info, category: .firebaseItemRepo, message: "Successfully created item \(item.id)")
        } catch {
            Logger.log(level: .error, category: .firebaseItemRepo, message: "Failed to create item \(item.id): \(error.localizedDescription)")
            throw error
        }
    }
    
    func updateItem<T: BaseItem>(_ item: T) async throws {
        Logger.log(level: .info, category: .firebaseItemRepo, message: "updateItem() called for item: \(item.id) of type: \(item.type.rawValue)")
        
        do {
            let docRef = db.collection("nests").document(nestId).collection(collectionName).document(item.id)
            try await docRef.setData(try Firestore.Encoder().encode(item))
            
            // Update cache - following smart cache update principles
            if var items = cachedItems {
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index] = item
                    cachedItems = items
                    Logger.log(level: .info, category: .firebaseItemRepo, message: "Updated item \(item.id) in cache")
                } else {
                    // Item not in cache, add it
                    items.append(item)
                    cachedItems = items
                    Logger.log(level: .info, category: .firebaseItemRepo, message: "Added updated item \(item.id) to cache")
                }
            }
            
            Logger.log(level: .info, category: .firebaseItemRepo, message: "Successfully updated item \(item.id)")
        } catch {
            Logger.log(level: .error, category: .firebaseItemRepo, message: "Failed to update item \(item.id): \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteItem(id: String) async throws {
        Logger.log(level: .info, category: .firebaseItemRepo, message: "deleteItem() called for id: \(id)")
        
        do {
            let docRef = db.collection("nests").document(nestId).collection(collectionName).document(id)
            try await docRef.delete()
            
            // Update cache - following smart cache update principles
            if var items = cachedItems {
                items.removeAll { $0.id == id }
                cachedItems = items
                Logger.log(level: .info, category: .firebaseItemRepo, message: "Removed item \(id) from cache")
            }
            
            Logger.log(level: .info, category: .firebaseItemRepo, message: "Successfully deleted item \(id)")
        } catch {
            Logger.log(level: .error, category: .firebaseItemRepo, message: "Failed to delete item \(id): \(error.localizedDescription)")
            throw error
        }
    }
    
    func clearItemsCache() {
        Logger.log(level: .info, category: .firebaseItemRepo, message: "clearItemsCache() called")
        cachedItems = nil
    }
    
    // MARK: - Private Methods
    
    private func decodeItem(from document: QueryDocumentSnapshot) throws -> any BaseItem {
        let data = document.data()
        return try decodeItemFromData(data, documentID: document.documentID, document: document)
    }
    
    private func decodeItem(from document: DocumentSnapshot) throws -> any BaseItem {
        guard let data = document.data() else {
            throw ItemRepositoryError.documentHasNoData(document.documentID)
        }
        return try decodeItemFromData(data, documentID: document.documentID, document: document)
    }
    
    private func decodeItemFromData(_ data: [String: Any], documentID: String, document: Any) throws -> any BaseItem {
        // Get type field, defaulting to "entry" for legacy documents (guiding principle #4)
        let typeString = data["type"] as? String ?? "entry"
        guard let itemType = ItemType(rawValue: typeString) else {
            Logger.log(level: .info, category: .firebaseItemRepo, message: "Unknown item type: \(typeString) for document \(documentID), defaulting to entry")
            
            // Try to decode as BaseEntry for unknown types
            if let queryDoc = document as? QueryDocumentSnapshot {
                return try queryDoc.data(as: BaseEntry.self)
            } else if let doc = document as? DocumentSnapshot {
                return try doc.data(as: BaseEntry.self)
            } else {
                throw ItemRepositoryError.unsupportedDocumentType
            }
        }
        
        Logger.log(level: .debug, category: .firebaseItemRepo, message: "Decoding item \(documentID) as type: \(itemType.rawValue)")
        
        switch itemType {
        case .entry:
            if let queryDoc = document as? QueryDocumentSnapshot {
                return try queryDoc.data(as: BaseEntry.self)
            } else if let doc = document as? DocumentSnapshot {
                return try doc.data(as: BaseEntry.self)
            } else {
                throw ItemRepositoryError.unsupportedDocumentType
            }
        case .place:
            if let queryDoc = document as? QueryDocumentSnapshot {
                return try queryDoc.data(as: PlaceItem.self)
            } else if let doc = document as? DocumentSnapshot {
                return try doc.data(as: PlaceItem.self)
            } else {
                throw ItemRepositoryError.unsupportedDocumentType
            }
        case .routine:
            // Future implementation - for now, throw error
            Logger.log(level: .error, category: .firebaseItemRepo, message: "Routine items not yet implemented")
            throw ItemRepositoryError.unsupportedItemType(itemType)
        }
    }
}

// MARK: - Errors
extension FirebaseItemRepository {
    enum ItemRepositoryError: LocalizedError {
        case unsupportedItemType(ItemType)
        case documentHasNoData(String)
        case unsupportedDocumentType
        
        var errorDescription: String? {
            switch self {
            case .unsupportedItemType(let type):
                return "Item type '\(type.rawValue)' is not yet supported"
            case .documentHasNoData(let documentID):
                return "Document '\(documentID)' has no data"
            case .unsupportedDocumentType:
                return "Unsupported document type for decoding"
            }
        }
    }
}
