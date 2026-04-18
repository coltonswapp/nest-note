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
        let pilot = PilotCardItem(category: "Test", title: "T", body: "B")
        let contact = ContactItem(category: "Test", title: "Name", phoneNumber: "+15551234567")
        let bucket = ItemBuckets(items: [pilot, contact])
        assert(bucket.pilotCards.count == 1, "ItemBuckets should route pilot_card items")
        assert(bucket.contacts.count == 1, "ItemBuckets should route contact items")
        assert(bucket.entries.isEmpty)
        Logger.log(level: .debug, category: .testing, message: "ItemBucketsSelfTest passed")
    }
}
#endif
