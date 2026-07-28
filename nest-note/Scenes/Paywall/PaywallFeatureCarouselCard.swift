//
//  PaywallFeatureCarouselCard.swift
//  nest-note
//

import Foundation

struct PaywallFeatureCarouselCard: Hashable {
    let id: String
    let feature: ProFeature
    let imageName: String
}

let paywallFeatureCarouselCards: [PaywallFeatureCarouselCard] = [
    .init(id: "unlimited", feature: .unlimitedEntries, imageName: "L1"),
    .init(id: "multiday", feature: .multiDaySessions, imageName: "L2"),
    .init(id: "events", feature: .sessionEvents, imageName: "L3"),
    .init(id: "review", feature: .nestReview, imageName: "L4"),
    .init(id: "pdf", feature: .sessionPDFExport, imageName: "L5"),
]
