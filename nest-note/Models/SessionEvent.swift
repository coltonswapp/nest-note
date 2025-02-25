//
//  SessionEvent.swift
//  nest-note
//
//  Created by Colton Swapp on 1/19/25.
//

import Foundation

struct SessionEvent: Hashable, Codable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var placeID: String?
    private var colorType: NNColors.EventColors.ColorType
    
    var eventColor: NNColors.NNColorPair {
        get { colorType.colorPair }
    }
    
    init(id: String = UUID().uuidString, title: String, startDate: Date, endDate: Date? = nil, placeId: String? = nil, eventColor: NNColors.EventColors.ColorType) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate ?? Calendar.current.date(byAdding: .minute, value: 30, to: startDate)!
        self.placeID = placeId
        self.colorType = eventColor
    }
}
