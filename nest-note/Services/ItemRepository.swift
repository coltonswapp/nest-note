//
//  ItemRepository.swift
//  nest-note
//
//  Created by Claude on 1/30/25.
//

import Foundation

// MARK: - ItemRepository Protocol
protocol ItemRepository {
    func fetchItems() async throws -> [BaseItem]
    func fetchItem(id: String) async throws -> BaseItem?
    func createItem<T: BaseItem>(_ item: T) async throws
    func updateItem<T: BaseItem>(_ item: T) async throws
    func deleteItem(id: String) async throws
    func clearItemsCache()
}