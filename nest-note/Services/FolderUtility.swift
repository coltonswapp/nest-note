import Foundation
import UIKit

/// Shared utility for folder operations across NestService and SitterViewService
final class FolderUtility {
    
    /// Represents the contents of a folder
    struct FolderContents {
        let entries: [BaseEntry]
        let places: [PlaceItem]
        let routines: [RoutineItem]
        let subfolders: [FolderData]
        let allPlaces: [PlaceItem] // For passing to child folders
    }
    
    /// Builds subfolders for a given category, counting both items and subfolders
    static func buildSubfolders(
        for category: String,
        allEntries: [String: [BaseEntry]],
        allPlaces: [PlaceItem],
        allRoutines: [RoutineItem],
        categories: [NestCategory]
    ) -> [FolderData] {
        var folderItems: [FolderData] = []
        var folderCounts: [String: Int] = [:]
        var currentLevelFolders: Set<String> = []
        
        // Count entries in subfolders
        for (_, categoryEntries) in allEntries {
            for entry in categoryEntries {
                let folderPath = entry.category
                
                // Check if this entry belongs to a subfolder of the current category
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
        }
        
        // Count places in subfolders
        for place in allPlaces {
            let folderPath = place.category
            
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
        
        // Count routines in subfolders
        for routine in allRoutines {
            let folderPath = routine.category
            
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
        
        // Count subfolders as items (recursive counting)
        let subFolderCounts = countSubfoldersRecursively(
            for: currentLevelFolders,
            allEntries: allEntries,
            allPlaces: allPlaces,
            allRoutines: allRoutines,
            categories: categories
        )
        
        // Add subfolder counts to the main counts
        for (folderPath, subfolderCount) in subFolderCounts {
            folderCounts[folderPath, default: 0] += subfolderCount
        }
        
        // Add empty folders from categories
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
        
        // Create FolderData objects
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
    
    /// Recursively counts subfolders within each folder path
    private static func countSubfoldersRecursively(
        for folderPaths: Set<String>,
        allEntries: [String: [BaseEntry]],
        allPlaces: [PlaceItem],
        allRoutines: [RoutineItem],
        categories: [NestCategory]
    ) -> [String: Int] {
        var subfolderCounts: [String: Int] = [:]
        
        for folderPath in folderPaths {
            let subfolders = buildSubfolders(
                for: folderPath,
                allEntries: allEntries,
                allPlaces: allPlaces,
                allRoutines: allRoutines,
                categories: categories
            )
            
            // Each subfolder counts as 1 item
            if !subfolders.isEmpty {
                subfolderCounts[folderPath] = subfolders.count
            }
        }
        
        return subfolderCounts
    }
    
    /// Efficiently builds folder counts for multiple categories at once
    static func buildFolderCounts(
        for targetCategories: [String],
        allGroupedEntries: [String: [BaseEntry]],
        allPlaces: [PlaceItem],
        allRoutines: [RoutineItem],
        categories: [NestCategory]
    ) -> [String: Int] {
        var folderCounts: [String: Int] = [:]
        
        // Initialize counts for all target categories
        for category in targetCategories {
            folderCounts[category] = 0
        }
        
        // Count entries efficiently in one pass
        for (_, categoryEntries) in allGroupedEntries {
            for entry in categoryEntries {
                let entryCategory = entry.category
                
                // Check if entry belongs to any target category
                for targetCategory in targetCategories {
                    if entryCategory == targetCategory || entryCategory.hasPrefix(targetCategory + "/") {
                        folderCounts[targetCategory, default: 0] += 1
                        break // Entry can only belong to one target category
                    }
                }
            }
        }
        
        // Count places efficiently in one pass
        for place in allPlaces {
            let placeCategory = place.category
            
            // Check if place belongs to any target category
            for targetCategory in targetCategories {
                if placeCategory == targetCategory || placeCategory.hasPrefix(targetCategory + "/") {
                    folderCounts[targetCategory, default: 0] += 1
                    break // Place can only belong to one target category
                }
            }
        }
        
        // Count routines efficiently in one pass
        for routine in allRoutines {
            let routineCategory = routine.category
            
            // Check if routine belongs to any target category
            for targetCategory in targetCategories {
                if routineCategory == targetCategory || routineCategory.hasPrefix(targetCategory + "/") {
                    folderCounts[targetCategory, default: 0] += 1
                    break // Routine can only belong to one target category
                }
            }
        }
        
        // Count subfolders for each target category
        for targetCategory in targetCategories {
            let subfolders = buildSubfolders(
                for: targetCategory,
                allEntries: allGroupedEntries,
                allPlaces: allPlaces,
                allRoutines: allRoutines,
                categories: categories
            )
            folderCounts[targetCategory, default: 0] += subfolders.count
        }
        
        return folderCounts
    }

    /// Builds folder contents for a specific category
    static func buildFolderContents(
        for category: String,
        allGroupedEntries: [String: [BaseEntry]],
        allPlaces: [PlaceItem],
        allRoutines: [RoutineItem],
        categories: [NestCategory]
    ) -> FolderContents {
        // Filter entries for this exact category
        let entries: [BaseEntry]
        if category.contains("/") {
            // For folder paths, find entries that match this exact path
            var matchingEntries: [BaseEntry] = []
            for (_, categoryEntries) in allGroupedEntries {
                for entry in categoryEntries {
                    if entry.category == category {
                        matchingEntries.append(entry)
                    }
                }
            }
            entries = matchingEntries
        } else {
            // For root categories, use the grouped entries
            entries = allGroupedEntries[category] ?? []
        }
        
        // Filter places for this category
        let places = allPlaces.filter { $0.category == category }
        
        // Filter routines for this category
        let routines = allRoutines.filter { $0.category == category }
        
        // Build subfolders
        let subfolders = buildSubfolders(
            for: category,
            allEntries: allGroupedEntries,
            allPlaces: allPlaces,
            allRoutines: allRoutines,
            categories: categories
        )
        
        return FolderContents(
            entries: entries,
            places: places,
            routines: routines,
            subfolders: subfolders,
            allPlaces: allPlaces
        )
    }
}