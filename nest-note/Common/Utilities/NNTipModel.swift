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
}


