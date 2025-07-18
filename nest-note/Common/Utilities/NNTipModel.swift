//
//  NNTipModel.swift
//  nest-note
//
//  Created by Colton Swapp on 7/10/25.
//
import UIKit

// MARK: - Custom Tip Model
struct NNTipModel {
    let id: String
    let title: String
    let message: String?
    let systemImageName: String
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

enum EntryDetailTips {

    static let entryTitleContentTip = NNTipModel(
        id: "EntryTitleContentTip",
        title: "Creating an entry is easy",
        message: "Please add both a title and content.",
        systemImageName: "doc.text"
    )

    static let entryDetailsTip = NNTipModel(
        id: "EntryDetailsTip",
        title: "More Entry Details",
        message: "See when an entry was created and last modified.",
        systemImageName: "hourglass"
    )

    static let visibilityLevelTip = NNTipModel(
        id: "VisibilityLevelTip",
        title: "Change Visibility",
        message: "Tap to adjust the visibility level of the entry.",
        systemImageName: "eye"
    )

    // MARK: - Tip Groups
    static let tipGroup: NNTipGroup = NNTipGroup(
        tips: [
            entryTitleContentTip,
            visibilityLevelTip
        ]
    )
}

enum NestCategoryTips {

    static let entrySuggestionTip = NNTipModel(
        id: "EntrySuggestionTip",
        title: "Need Inspiration?",
        message: "Browse our collection of entry suggestions.",
        systemImageName: "sparkles"
    )
}

enum OwnerHomeTips {
    
    static let finishSetupTip = NNTipModel(
        id: "FinishSetupTip",
        title: "Complete Your Setup",
        message: "Tap here to finish setting up your nest and unlock all features.",
        systemImageName: "checkmark.circle"
    )
    
    static let yourNestTip = NNTipModel(
        id: "YourNestTip",
        title: "Tap to view Your Nest",
        message: "This is where all your entries live, grouped into categories.",
        systemImageName: "rectangle.stack.fill"
    )
}

enum PlaceListTips {
    
    static let placeSuggestionTip = NNTipModel(
        id: "PlaceSuggestionTip",
        title: "Need Inspiration?",
        message: "Browse our collection of place suggestions.",
        systemImageName: "sparkles"
    )
    
    static let chooseOnMapTip = NNTipModel(
        id: "ChooseOnMapTip",
        title: "Quick Add",
        message: "Tap here to quickly find and select an address",
        systemImageName: "mappin.and.ellipse"
    )
}

enum PlaceDetailTips {
    
    static let editLocationTip = NNTipModel(
        id: "EditLocationTip",
        title: "Edit Location",
        message: "Change the address of a place here.",
        systemImageName: "mappin.and.ellipse"
    )
}

enum SettingsTips {
    static let profileTip = NNTipModel(
        id: "ProfileTip",
        title: "Account Details",
        message: "Tap here to manage your account.",
        systemImageName: "person.crop.square"
    )
    
    static let sessionsTip = NNTipModel(
        id: "SessionsTip",
        title: "Your Sessions Live Here",
        message: "Tap to see in-progress, upcoming, & past sessions.",
        systemImageName: "rectangle.fill.on.rectangle.angled.fill"
    )
}

enum NestViewTips {
    static let getDirectionsTip = NNTipModel(
        id: "GetDirectionsTip",
        title: "Get Directions",
        message: "Tap here to get directions to the nest",
        systemImageName: "location"
    )
}

enum HomeTips {
    static let happeningNowTip = NNTipModel(
        id: "HappeningNowTip",
        title: "Happening Now",
        message: "This is where you can quickly access the details of a session happening currently",
        systemImageName: "clock"
    )
}


