# Unified Collection Architecture Plan

## Executive Summary


  Migrate nest-note's data architecture from separate collections to a unified collection system, enabling seamless display of entries
  and places together while improving performance and simplifying data management.

  ---
  Problem Statement

  Currently, entries and places are stored in separate Firebase collections (entries and places), requiring:
  - Multiple network calls to fetch related data
  - Separate caching mechanisms that can become inconsistent
  - Complex UI logic to coordinate display of different data types
  - Difficulty displaying entries and places together in a unified interface

  ---
  Solution Overview

  Implement a unified collection architecture where all items (entries, places, and future routines) are stored in a single entries
  collection, differentiated by a type field.

  ---
  Goals & Success Metrics

  Primary Goals

  - Performance: Reduce network calls by 50% through unified fetching
  - Consistency: Eliminate cache synchronization issues
  - Flexibility: Enable unified display of entries and places in UICollectionView
  - Scalability: Create extensible architecture for future item types (routines)

  Success Metrics

  - Single network call replaces multiple separate fetches
  - Unified caching reduces memory usage and improves consistency
  - Places displayed alongside entries in category views
  - Codebase complexity reduced through elimination of duplicate logic

  ---
  Technical Requirements

  Data Model Changes

  New Base Protocol: BaseItem
  protocol BaseItem: Codable, Hashable, Identifiable {
      var id: String { get }
      var type: ItemType { get }
      var category: String { get set }
      var title: String { get set }
      var createdAt: Date { get }
      var updatedAt: Date { get set }
  }

  Item Type Enumeration
  enum ItemType: String, CaseIterable, Codable {
      case entry = "entry"
      case place = "place"
      case routine = "routine" // Future implementation
  }

  Concrete Item Types
  struct EntryItem: BaseItem {
      let type: ItemType = .entry
      var content: String
      // ... other entry-specific properties
  }

  struct PlaceItem: BaseItem {
      let type: ItemType = .place
      var address: String
      var coordinate: GeoPoint
      var isTemporary: Bool
      var thumbnailURLs: ThumbnailURLs?
      // ... other place-specific properties
  }

  Collection Architecture

  Before:
  - nests/{nestId}/entries/ - Entry documents
  - nests/{nestId}/places/ - Place documents

  After:
  - nests/{nestId}/entries/ - All item documents with type field

  Repository Pattern

  New ItemRepository Interface
  protocol ItemRepository {
      func fetchItems() async throws -> [BaseItem]
      func fetchItem(id: String) async throws -> BaseItem?
      func createItem<T: BaseItem>(_ item: T) async throws
      func updateItem<T: BaseItem>(_ item: T) async throws
      func deleteItem(id: String) async throws
      func clearItemsCache()
  }

  NestService Integration
  - Maintain existing EntryRepository interface for backward compatibility
  - Internally use ItemRepository for all operations
  - Convert between BaseEntry and EntryItem as needed
  - Preserve cachedEntries for existing code compatibility
  
  Legacy Document Handling
  - Documents without a type field are automatically assumed to be entries
  - No migration from places collection - that collection is dead and gone
  - Only the entries collection will be accessed going forward

  ---
  Guiding Principles
  
  Cache-First Architecture
  - NestService prioritizes cached information for all read operations
  - Always check cache first unless items are directly updated
  - Only fetch from network when cache is empty or explicitly refreshed
  
  Smart Cache Updates
  - When making updates, modify the cached element directly rather than re-fetching
  - Maintain cache consistency by updating in-memory objects after successful writes
  - Avoid unnecessary network calls through intelligent cache management
  
  Comprehensive Logging
  - All core logic must include Logger calls for debugging and monitoring
  - Log operations to identify duplicate calls, failing logic, and performance issues
  - Include meaningful context in log messages (item IDs, operation types, cache states)

  ---
  Implementation Plan

  Phase 1: Foundation
  
  1. Create BaseItem protocol and concrete implementations
  2. Implement FirebaseItemRepository with unified collection access
  3. Add type-safe decoding logic for different item types
  4. Implement type defaulting: documents without type field → assume "entry"

  Phase 2: Service Migration

  1. Update NestService to use ItemRepository internally
  2. Update SitterViewService to use ItemRepository internally
  3. Add generic CRUD methods for all BaseItem types
  4. Add type-specific convenience methods for places
  5. Maintain existing method signatures for compatibility
  6. Remove PlacesService entirely - consolidate into NestService
  7. Remove any PlacesService imports and references throughout codebase
  8. Add logic to handle documents without type field (assume entry type)

  Phase 3: UI Integration

  1. Update NestCategoryViewController to display places alongside entries
  2. Implement unified data loading with single network call
  3. Add place-specific cells and layouts to collection view
  4. Update move operations to handle both entries and places
  5. Remove separate place-fetching logic from UI controllers
  6. Remove duplicate collection view cells/layouts for places if any exist

  Phase 4: Final Cleanup & Optimization

  1. Remove any remaining place-specific repository patterns
  2. Remove unused imports and dead code (use Xcode warnings)
  3. Use "Find Call Hierarchy" to identify and remove unreferenced methods
  4. Eliminate any remaining duplicate caching mechanisms
  5. Performance testing and optimization

---

## Sitter Session Entry Filtering

### Problem Statement

Currently, sitters using SitterViewService see ALL entries in a nest when viewing an active session. However, owners should be able to control which specific entries are relevant and visible to sitters for each babysitting session.

### Solution Overview

Enhance the existing SitterViewService to filter entries based on a session-specific `entryIds` array, providing sitters with only the entries relevant to their current session while maintaining the existing architectural patterns.

### Technical Implementation

#### Session Model Enhancement
- Ensure `SessionItem` includes `entryIds: [String]?` property for storing selected entry IDs
- Entry selection UI already exists and handles this array

#### SitterViewService Filtering Enhancement
Update `fetchNestEntries()` method in SitterViewService to:
1. Check if current session has `entryIds` array populated
2. Filter fetched entries to only include those with IDs in the allowed list
3. Maintain backward compatibility: if `entryIds` is nil/empty, show all entries
4. Preserve existing caching and performance patterns

#### Filtering Logic
```swift
// In SitterViewService.fetchNestEntries()
let allEntries = // ... existing fetch logic
let allowedEntryIds = currentSession?.entryIds

if let allowedIds = allowedEntryIds, !allowedIds.isEmpty {
    // Filter entries to only those in the session's allowed list
    filteredEntries = allEntries.filter { allowedIds.contains($0.id) }
} else {
    // Backward compatibility: show all entries if no filtering specified
    filteredEntries = allEntries
}
```

### Implementation Benefits

- **Minimal Code Changes**: Leverages existing SitterViewService architecture
- **Consistent UI**: NestViewController continues using EntryRepository protocol
- **Performance**: Same caching and network patterns maintained
- **Owner Control**: Owners can precisely control what sitters see per session

### Integration with Unified Collection Architecture

This sitter filtering enhancement works seamlessly with the unified collection architecture:
- SitterViewService already uses ItemRepository internally
- Filtering applies to converted BaseEntry objects after ItemRepository fetch
- Places can also be filtered using the same pattern if needed in future
- No additional repository layers or architectural changes required

---

*This plan provides a comprehensive approach to unifying the collections while maintaining data integrity and user experience. The phased approach allows for careful validation at each step.*
