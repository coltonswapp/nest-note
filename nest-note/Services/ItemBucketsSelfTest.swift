//
//  ItemBucketsSelfTest.swift
//  nest-note
//
//  Lightweight DEBUG validation for the extensible item grouping path (no XCTest target in project).
//

import Foundation

#if DEBUG
enum ItemBucketsSelfTest {
    static func run() {
        let contact = ContactItem(category: "Test", title: "Name", phoneNumber: "+15551234567")
        let bucket = ItemBuckets(items: [contact])
        assert(bucket.contacts.count == 1, "ItemBuckets should route contact items")
        assert(bucket.notes.isEmpty)
        Logger.log(level: .debug, category: .testing, message: "ItemBucketsSelfTest passed")
    }
}
#endif
