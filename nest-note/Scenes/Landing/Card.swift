//
//  Card.swift
//  AppleInvites
//
//  Created by Luis Filipe Pedroso on 27/03/25.
//
import Foundation
import SwiftUI

struct Card: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var image: String
}

let cards: [Card] = [
    .init(image: "L1"),
    .init(image: "L2"),
    .init(image: "L3"),
    .init(image: "L4"),
    .init(image: "L5"),
    .init(image: "L6"),
]
