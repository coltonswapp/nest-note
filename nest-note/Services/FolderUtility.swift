import Foundation
import UIKit

/// Shared utility for folder operations across NestService and SitterViewService
final class FolderUtility {

    /// Represents the contents of a folder (typed buckets + subfolders).
    struct FolderContents {
        let buckets: ItemBuckets
        let subfolders: [FolderData]
        let allPlaces: [PlaceItem]

        var entries: [BaseEntry] { buckets.entries }
        var places: [PlaceItem] { buckets.places }
        var routines: [RoutineItem] { buckets.routines }
        var pilotCards: [PilotCardItem] { buckets.pilotCards }
        var contacts: [ContactItem] { buckets.contacts }
        var unknownItems: [UnknownItem] { buckets.unknownItems }
    }

    /// Builds subfolders for a given category, counting both items and subfolders
    static func buildSubfolders(
        for category: String,
        allItems: [BaseItem],
        categories: [NestCategory]
    ) -> [FolderData] {
        var folderItems: [FolderData] = []
        var folderCounts: [String: Int] = [:]
        var currentLevelFolders: Set<String> = []

        for item in allItems {
            let folderPath = item.category
            if folderPath.hasPrefix(category + "/") {
                let remainingPath = String(folderPath.dropFirst(category.count + 1))
                if !remainingPath.isEmpty {
                    let nextFolderComponent = remainingPath.components(separatedBy: "/").first!
                    let nextFolderPath = "\(category)/\(nextFolderComponent)"
                    currentLevelFolders.insert(nextFolderPath)
                    folderCounts[nextFolderPath, default: 0] += 1
                }
            }
        }

        let subFolderCounts = countSubfoldersRecursively(
            for: currentLevelFolders,
            allItems: allItems,
            categories: categories
        )

        for (folderPath, subfolderCount) in subFolderCounts {
            folderCounts[folderPath, default: 0] += subfolderCount
        }

        for nestCategory in categories {
            let folderPath = nestCategory.name
            if folderPath.hasPrefix(category + "/") {
                let remainingPath = String(folderPath.dropFirst(category.count + 1))
                if !remainingPath.isEmpty && !remainingPath.contains("/") {
                    currentLevelFolders.insert(folderPath)
                    if folderCounts[folderPath] == nil {
                        folderCounts[folderPath] = 0
                    }
                }
            }
        }

        for folderPath in currentLevelFolders.sorted() {
            let folderName = folderPath.components(separatedBy: "/").last ?? folderPath
            let matchingCategory = categories.first { $0.name == folderPath }
            let iconName = matchingCategory?.symbolName ?? "folder"
            let image = UIImage(systemName: iconName)

            let folderData = FolderData(
                title: folderName,
                image: image,
                itemCount: folderCounts[folderPath] ?? 0,
                fullPath: folderPath,
                category: matchingCategory
            )
            folderItems.append(folderData)
        }

        return folderItems
    }

    private static func countSubfoldersRecursively(
        for folderPaths: Set<String>,
        allItems: [BaseItem],
        categories: [NestCategory]
    ) -> [String: Int] {
        var subfolderCounts: [String: Int] = [:]

        for folderPath in folderPaths {
            let subfolders = buildSubfolders(
                for: folderPath,
                allItems: allItems,
                categories: categories
            )

            if !subfolders.isEmpty {
                subfolderCounts[folderPath] = subfolders.count
            }
        }

        return subfolderCounts
    }

    /// Efficiently builds folder counts for multiple categories at once
    static func buildFolderCounts(
        for targetCategories: [String],
        allItems: [BaseItem],
        categories: [NestCategory]
    ) -> [String: Int] {
        var folderCounts: [String: Int] = [:]

        for category in targetCategories {
            folderCounts[category] = 0
        }

        for item in allItems {
            let itemCategory = item.category
            for targetCategory in targetCategories {
                if itemCategory == targetCategory || itemCategory.hasPrefix(targetCategory + "/") {
                    folderCounts[targetCategory, default: 0] += 1
                    break
                }
            }
        }

        for targetCategory in targetCategories {
            let subfolders = buildSubfolders(
                for: targetCategory,
                allItems: allItems,
                categories: categories
            )
            folderCounts[targetCategory, default: 0] += subfolders.count
        }

        return folderCounts
    }

    /// Builds folder contents for a specific category
    static func buildFolderContents(
        for category: String,
        allItems: [BaseItem],
        categories: [NestCategory]
    ) -> FolderContents {
        let bucket = ItemBuckets(items: allItems).items(inCategory: category)

        let subfolders = buildSubfolders(
            for: category,
            allItems: allItems,
            categories: categories
        )

        let allPlacesInNest = ItemBuckets(items: allItems).places

        return FolderContents(
            buckets: bucket,
            subfolders: subfolders,
            allPlaces: allPlacesInNest
        )
    }
}
