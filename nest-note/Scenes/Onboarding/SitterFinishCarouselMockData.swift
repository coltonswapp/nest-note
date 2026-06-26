//
//  SitterFinishCarouselMockData.swift
//  nest-note
//

import Foundation
import UIKit

struct SitterFinishCarouselItem: Identifiable {
    let id: String
    let session: SessionItem
    let invite: Invite
    let bannerTintColor: UIColor
}

enum SitterFinishCarouselMockData {
    static let items: [SitterFinishCarouselItem] = makeItems()

    private static func makeItems() -> [SitterFinishCarouselItem] {
        let now = Date()
        let day: TimeInterval = 24 * 60 * 60

        let definitions: [(nestID: String, nestName: String, title: String, startOffset: TimeInterval, endOffset: TimeInterval, isMultiDay: Bool)] = [
            ("nest-miller", "The Miller Nest", "Date Night", day, day + 4 * 3600, false),
            ("nest-anderson", "Anderson Family Nest", "Spring Break", 2 * day, 6 * day, true),
            ("nest-park", "Park Household", "Weekend Getaway", 3 * day, 5 * day, true),
            ("nest-chen", "The Chen Nest", "Anniversary Dinner", 4 * day, 4 * day + 5 * 3600, false),
            ("nest-williams", "Williams Family Nest", "Business Trip", 5 * day, 8 * day, true),
            ("nest-garcia", "Garcia Nest", "Birthday Party", 6 * day, 6 * day + 6 * 3600, false),
            ("nest-thompson", "Thompson Household", "Holiday Coverage", 7 * day, 10 * day, true),
            ("nest-rivera", "The Rivera Nest", "Family Reunion", 8 * day, 11 * day, true),
        ]

        let tintColors = NNColors.EventColors.ColorType.allCases
            .filter { $0 != .yellow }
            .map { $0.colorPair.border }
            .shuffled()

        return definitions.enumerated().map { index, definition in
            let sessionID = "session-mock-\(index + 1)"
            let session = SessionItem(
                id: sessionID,
                title: definition.title,
                startDate: now.addingTimeInterval(definition.startOffset),
                endDate: now.addingTimeInterval(definition.endOffset),
                isMultiDay: definition.isMultiDay,
                nestID: definition.nestID
            )

            let invite = Invite(
                id: "invite-mock-\(index + 1)",
                nestID: definition.nestID,
                nestName: definition.nestName,
                sessionID: sessionID,
                sitterEmail: nil,
                status: .pending,
                createdAt: now,
                expiresAt: now.addingTimeInterval(48 * 60 * 60),
                createdBy: "owner-mock-\(index + 1)"
            )

            return SitterFinishCarouselItem(
                id: invite.id,
                session: session,
                invite: invite,
                bannerTintColor: tintColors[index % tintColors.count]
            )
        }
    }
}
