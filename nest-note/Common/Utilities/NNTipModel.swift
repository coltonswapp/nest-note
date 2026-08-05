//
//  NNTipModel.swift
//  nest-note
//
//  Created by Colton Swapp on 7/10/25.
//
import UIKit

/// Which app mode(s) a tip can appear in.
enum TipAudience: String, Hashable {
    case owner = "Owner"
    case sitter = "Sitter"
    case both = "Both modes"
}

// MARK: - Custom Tip Model
struct NNTipModel: Hashable {
    let id: String
    let title: String
    let message: String?
    let systemImageName: String
    /// Owner / Sitter / both — for debug tooling.
    let audience: TipAudience
    /// Short human-readable show conditions (mode context + gates).
    let criteria: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: NNTipModel, rhs: NNTipModel) -> Bool {
        lhs.id == rhs.id
    }
}

protocol NNTipGroupProtocol {
    var tips: [NNTipModel] { get }
}

struct NNTipGroup: NNTipGroupProtocol {
    var tips: [NNTipModel]
    
    init(tips: [NNTipModel]) {
        self.tips = tips
    }
}

/// Named groups of tips for debug reset UI and catalog listing.
struct NNTipSection: Hashable {
    let title: String
    let tips: [NNTipModel]
}

/// Central registry of every tip in the app, grouped by feature area.
enum NNTipCatalog {
    static let sections: [NNTipSection] = [
        NNTipSection(title: "Note Detail", tips: [
            NoteDetailTips.noteTitleContentTip,
            NoteDetailTips.noteDetailsTip,
        ]),
        NNTipSection(title: "Attachments", tips: [
            AttachmentTips.attachItemsTip,
        ]),
        NNTipSection(title: "Owner Home", tips: [
            OwnerHomeTips.yourNestTip,
        ]),
        NNTipSection(title: "Home", tips: [
            HomeTips.happeningNowTip,
        ]),
        NNTipSection(title: "Nest", tips: [
            NestViewTips.getDirectionsTip,
        ]),
        NNTipSection(title: "Places", tips: [
            PlaceListTips.placeSuggestionTip,
            PlaceListTips.chooseOnMapTip,
            PlaceDetailTips.editLocationTip,
        ]),
        NNTipSection(title: "Settings", tips: [
            SettingsTips.profileTip,
            SettingsTips.sessionsTip,
        ]),
    ]

    static var allTips: [NNTipModel] {
        sections.flatMap(\.tips)
    }
}

enum NoteDetailTips {

    static let noteTitleContentTip = NNTipModel(
        id: "EntryTitleContentTip",
        title: "Note Tips",
        message: "Give it a clear title like 'Garage Code' and add the details that could be useful.",
        systemImageName: "doc.text",
        audience: .owner,
        criteria: "New empty note"
    )

    static let noteDetailsTip = NNTipModel(
        id: "EntryDetailsTip",
        title: "More Note Details",
        message: "See when a note was created and last modified.",
        systemImageName: "hourglass",
        audience: .owner,
        criteria: "New empty note · after 6 Note Detail visits"
    )

    // MARK: - Tip Groups
    static let tipGroup: NNTipGroup = NNTipGroup(
        tips: [
            noteTitleContentTip,
            noteDetailsTip
        ]
    )
}

enum AttachmentTips {
    static let attachItemsTip = NNTipModel(
        id: "AttachItemsTip",
        title: "Attach Related Items",
        message: "Link notes, places, or routines so everything sitters need is right here.",
        systemImageName: "paperclip",
        audience: .owner,
        criteria: "Editable note, place, or routine"
    )
}

enum OwnerHomeTips {
    
    static let yourNestTip = NNTipModel(
        id: "YourNestTip",
        title: "Tap to view Your Nest",
        message: "This is where all your notes live, grouped into categories.",
        systemImageName: "rectangle.stack.fill",
        audience: .owner,
        criteria: "Home · nest cell visible"
    )
}

enum PlaceListTips {
    
    static let placeSuggestionTip = NNTipModel(
        id: "PlaceSuggestionTip",
        title: "Need Inspiration?",
        message: "Browse our collection of place suggestions.",
        systemImageName: "sparkles",
        audience: .owner,
        criteria: "Places list · not selecting"
    )
    
    static let chooseOnMapTip = NNTipModel(
        id: "ChooseOnMapTip",
        title: "Quick Add",
        message: "Tap here to quickly find and select an address",
        systemImageName: "mappin.and.ellipse",
        audience: .owner,
        criteria: "Place selection mode"
    )
}

enum PlaceDetailTips {
    
    static let editLocationTip = NNTipModel(
        id: "EditLocationTip",
        title: "Edit Location",
        message: "Change the address of a place here.",
        systemImageName: "mappin.and.ellipse",
        audience: .owner,
        criteria: "Existing place · after 3 Place Detail visits"
    )
}

enum SettingsTips {
    static let profileTip = NNTipModel(
        id: "ProfileTip",
        title: "Account Details",
        message: "Tap here to manage your account.",
        systemImageName: "person.crop.square",
        audience: .both,
        criteria: "Settings · after 3 Settings visits"
    )
    
    static let sessionsTip = NNTipModel(
        id: "SessionsTip",
        title: "Your Sessions Live Here",
        message: "Tap to see in-progress, upcoming, & past sessions.",
        systemImageName: "rectangle.fill.on.rectangle.angled.fill",
        audience: .owner,
        criteria: "Settings · My Nest section visible"
    )
}

enum NestViewTips {
    static let getDirectionsTip = NNTipModel(
        id: "GetDirectionsTip",
        title: "Get Directions",
        message: "Tap here to get directions to the nest",
        systemImageName: "location",
        audience: .sitter,
        criteria: "Sitter nest view · address cell"
    )
}

enum HomeTips {
    static let happeningNowTip = NNTipModel(
        id: "HappeningNowTip",
        title: "Happening Now",
        message: "This is where you can quickly access the details of a session happening currently",
        systemImageName: "clock",
        audience: .both,
        criteria: "Home · active session section visible"
    )
}
