//
//  AttachmentResolver.swift
//  nest-note
//

import Foundation

enum AttachmentResolver {
    static let maxCount = 3

    /// Resolves attachment IDs against a nest item snapshot, preserving order and dropping missing IDs.
    static func resolve(
        ids: [String],
        from items: [BaseItem],
        excludingHostId: String? = nil
    ) -> [BaseItem] {
        let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var result: [BaseItem] = []
        var seen = Set<String>()

        for id in ids {
            guard !id.isEmpty, id != excludingHostId, !seen.contains(id) else { continue }
            guard let item = byId[id] else { continue }
            seen.insert(id)
            result.append(item)
            if result.count >= maxCount { break }
        }
        return result
    }

    /// Returns attachment IDs that still exist in `items`, normalized and capped.
    static func prune(
        ids: [String],
        against items: [BaseItem],
        excludingHostId: String? = nil
    ) -> [String] {
        resolve(ids: ids, from: items, excludingHostId: excludingHostId).map(\.id)
    }
}
