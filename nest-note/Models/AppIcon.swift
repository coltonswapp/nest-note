//
//  AppIcon.swift
//  nest-note
//
//  Created by Colton Swapp on 12/6/24.
//

import UIKit

enum AppIcon: String, CaseIterable {
    case main = "icon_main"
    case dark = "icon_dark"
    case green = "icon_green"
    case pattern = "icon_pattern"
    case dev = "icon_dev"
    
    var displayName: String {
        switch self {
        case .main:
            return "Default"
        case .dark:
            return "Dark"
        case .green:
            return "Green"
        case .pattern:
            return "Pattern"
        case .dev:
            return "TestFlight"
        }
    }
    
    var iconName: String? {
        switch self {
        case .main:
            return nil // Default icon
        case .dark:
            return "icon-dark"
        case .green:
            return "icon-green"
        case .pattern:
            return "icon-pattern"
        case .dev:
            return "icon-dev"
        }
    }
    
    var previewImageName: String {
        return rawValue + "-preview"
    }
    
    var isSelected: Bool {
        let currentIconName = UIApplication.shared.alternateIconName
        return currentIconName == iconName
    }
    
    static var current: AppIcon {
        let currentIconName = UIApplication.shared.alternateIconName
        return AppIcon.allCases.first { $0.iconName == currentIconName } ?? .main
    }
}
