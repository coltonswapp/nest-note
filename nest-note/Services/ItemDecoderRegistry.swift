//
//  ItemDecoderRegistry.swift
//  nest-note
//

import Foundation
import FirebaseFirestore

/// Central registry for decoding Firestore `entries` documents by `type`.
/// Add new types by registering a closure in `registerDecoders`.
enum ItemDecoderRegistry {

    private static var extraDecoders: [ItemType: (DocumentSnapshot) throws -> any BaseItem] = [:]

    static func registerDecoder(for itemType: ItemType, decode: @escaping (DocumentSnapshot) throws -> any BaseItem) {
        extraDecoders[itemType] = decode
    }

    static func decode(document: DocumentSnapshot) throws -> any BaseItem {
        guard let data = document.data() else {
            throw FirebaseItemRepository.ItemRepositoryError.documentHasNoData(document.documentID)
        }
        let typeString = data["type"] as? String ?? "entry"

        if let known = ItemType(rawValue: typeString) {
            return try decodeKnown(type: known, document: document, typeString: typeString)
        }

        Logger.log(
            level: .info,
            category: .firebaseItemRepo,
            message: "Unknown Firestore item type '\(typeString)' for \(document.documentID) — wrapping as UnknownItem"
        )
        Tracker.shared.track(.unknownNestItemDecoded)
        return try UnknownItem.fromFirestore(document: document, originalTypeString: typeString)
    }

    private static func decodeKnown(type: ItemType, document: DocumentSnapshot, typeString: String) throws -> any BaseItem {
        if let custom = extraDecoders[type] {
            return try custom(document)
        }
        switch type {
        case .entry:
            return try document.data(as: BaseEntry.self)
        case .place:
            return try document.data(as: PlaceItem.self)
        case .routine:
            return try document.data(as: RoutineItem.self)
        case .pilotCard:
            return try document.data(as: PilotCardItem.self)
        case .contact:
            return try document.data(as: ContactItem.self)
        case .unknownDocument:
            return try UnknownItem.fromFirestore(document: document, originalTypeString: typeString)
        }
    }
}
