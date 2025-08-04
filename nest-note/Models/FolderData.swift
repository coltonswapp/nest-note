//
//  FolderData.swift
//  nest-note
//
//  Created by Colton Swapp on 7/26/25.
//

import UIKit

struct FolderData: Hashable {
    let title: String
    let image: UIImage?
    let itemCount: Int
    let fullPath: String // The complete folder path (e.g., "dog/archie")
    let category: NestCategory? // Reference to the original category for icon
    let selectedCount: Int // Number of selected entries in this folder (for edit mode)
    
    init(title: String, image: UIImage?, itemCount: Int, fullPath: String, category: NestCategory? = nil, selectedCount: Int = 0) {
        self.title = title
        self.image = image
        self.itemCount = itemCount
        self.fullPath = fullPath
        self.category = category
        self.selectedCount = selectedCount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(fullPath)
    }
    
    static func == (lhs: FolderData, rhs: FolderData) -> Bool {
        return lhs.fullPath == rhs.fullPath
    }
}