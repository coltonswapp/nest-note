# Unified Collection Architecture Plan

## Executive Summary

This document outlines the migration from separate `entries` and `places` collections to a unified `entries` collection supporting multiple document types (Entry, Place, Routine). This consolidation will simplify data management, improve the Select Items flow, and provide a foundation for future item types.

## Current State Analysis

### Existing Collections
- **entries**: User-created journal entries with categories
- **places**: Location-based items with categories
- **Shared Structure**: Both use the same category system (`pets/dogs`, `household`, etc.)

### Current Pain Points
- Duplicate repository patterns
- Separate selection flows
- Code duplication across similar features
- Complex cross-collection queries

## Proposed Architecture

### Document Structure

```swift
// Base protocol for all item types
protocol BaseItem: Codable, Hashable {
    var id: String { get }
    var type: ItemType { get }
    var category: String { get }
    var title: String { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

enum ItemType: String, Codable, CaseIterable {
    case entry = "entry"
    case place = "place" 
    case routine = "routine"
}

// Concrete implementations
struct EntryItem: BaseItem {
    let id: String
    let type: ItemType = .entry
    let category: String
    let title: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
    // Entry-specific fields...
}

struct PlaceItem: BaseItem {
    let id: String
    let type: ItemType = .place
    let category: String
    let title: String
    let address: String?
    let coordinates: GeoPoint?
    let createdAt: Date
    let updatedAt: Date
    // Place-specific fields...
}

struct RoutineItem: BaseItem {
    let id: String
    let type: ItemType = .routine
    let category: String
    let title: String
    let steps: [String]
    let frequency: RoutineFrequency
    let createdAt: Date
    let updatedAt: Date
    // Routine-specific fields...
}
```

### Firestore Document Structure

```
entries/{itemId}
{
  "type": "entry" | "place" | "routine",
  "category": "pets/dogs",
  "title": "...",
  "createdAt": timestamp,
  "updatedAt": timestamp,
  
  // Type-specific fields stored directly in document
  // Entry fields:
  "content": "...",
  
  // Place fields:
  "address": "...",
  "coordinates": geopoint,
  
  // Routine fields:
  "steps": ["step1", "step2"],
  "frequency": "daily"
}
```

## Implementation Plan

### Phase 1: Repository Layer Unification (Week 1)

#### 1.1 Create Unified Repository
```swift
protocol ItemRepository {
    func fetchItems(type: ItemType?, category: String?) async throws -> [BaseItem]
    func fetchItem(id: String) async throws -> BaseItem?
    func createItem<T: BaseItem>(_ item: T) async throws
    func updateItem<T: BaseItem>(_ item: T) async throws
    func deleteItem(id: String) async throws
}

class FirebaseItemRepository: ItemRepository {
    private let db = Firestore.firestore()
    private let collection = "entries"
    
    func fetchItems(type: ItemType? = nil, category: String? = nil) async throws -> [BaseItem] {
        var query: Query = db.collection(collection)
        
        if let type = type {
            query = query.whereField("type", isEqualTo: type.rawValue)
        }
        
        if let category = category {
            query = query.whereField("category", isEqualTo: category)
        }
        
        // Implementation details...
    }
}
```

#### 1.2 Update Existing Repositories
- Mark `EntryRepository` and `PlaceRepository` as deprecated
- Create adapter pattern to maintain backward compatibility
- Gradually migrate method calls to new unified repository

### Phase 2: Data Migration (Week 2)

#### 2.1 Migration Strategy
```swift
class DataMigrationService {
    func migrateToUnifiedCollection() async throws {
        // 1. Add "type": "entry" to all existing entries
        try await addTypeFieldToEntries()
        
        // 2. Copy places to entries collection with "type": "place"
        try await migratePlacesToEntries()
        
        // 3. Verify data integrity
        try await validateMigration()
        
        // 4. Update user preferences/flags
        try await markMigrationComplete()
    }
    
    private func addTypeFieldToEntries() async throws {
        // Batch update existing entries
    }
    
    private func migratePlacesToEntries() async throws {
        // Copy places with type field
    }
}
```

#### 2.2 Rollback Plan
- Keep original places collection during migration period
- Implement feature flag to switch between old/new systems
- Monitor for 2 weeks before permanent deletion

### Phase 3: UI Layer Updates (Week 3)

#### 3.1 Update SelectEntriesFlowViewController
```swift
// Current: Only shows entries
// New: Shows all item types with filtering options

class SelectItemsFlowViewController: UIViewController {
    private var allowedTypes: Set<ItemType> = [.entry, .place, .routine]
    private var selectedItems: Set<BaseItem> = []
    
    // Filter UI for item types
    private func setupTypeFilter() {
        // Segmented control or filter buttons
    }
}
```

#### 3.2 Update Collection View Cells
```swift
// Enhanced FolderCollectionViewCell to show mixed content
func configure(with data: FolderData) {
    // Show counts per type
    // "3 entries, 2 places"
    updateSubtitle(for: data.typeCounts)
}
```

#### 3.3 Update Category Views
```swift
// NestCategoryViewController enhancements
enum DisplayMode {
    case all
    case entries
    case places
    case routines
}
```

### Phase 4: Enhanced Features (Week 4)

#### 4.1 Cross-Type Search
```swift
class UnifiedSearchService {
    func search(query: String, types: Set<ItemType>) async throws -> [BaseItem]
}
```

#### 4.2 Type-Specific Actions
```swift
// Context menus based on item type
func contextMenu(for item: BaseItem) -> UIMenu {
    switch item.type {
    case .entry:
        return entryContextMenu(for: item as! EntryItem)
    case .place:
        return placeContextMenu(for: item as! PlaceItem)
    case .routine:
        return routineContextMenu(for: item as! RoutineItem)
    }
}
```

## Technical Considerations

### Firestore Indexes Required
```
// Composite indexes needed:
- category ASC, type ASC
- type ASC, createdAt DESC
- category ASC, type ASC, createdAt DESC
```

### Type Safety
```swift
// Generic type casting with safety
extension ItemRepository {
    func fetchEntries(category: String? = nil) async throws -> [EntryItem] {
        let items = try await fetchItems(type: .entry, category: category)
        return items.compactMap { $0 as? EntryItem }
    }
}
```

### Backward Compatibility
```swift
// Adapter for existing code
class EntryRepositoryAdapter: EntryRepository {
    private let itemRepository: ItemRepository
    
    func fetchEntries() async throws -> [BaseEntry] {
        let items = try await itemRepository.fetchItems(type: .entry)
        return items.map { BaseEntry(from: $0) }
    }
}
```

## Benefits Realized

### 1. Simplified Select Flow
- Single interface for selecting any item type
- Unified selection state management
- Consistent filtering and search

### 2. Reduced Code Duplication
- Single repository pattern
- Shared UI components
- Common data structures

### 3. Future-Proof Architecture
- Easy addition of new item types
- Flexible querying capabilities
- Consistent patterns across features

### 4. Improved Performance
- Single collection queries
- Better caching strategies
- Reduced complexity

## Migration Timeline

### Week 1: Foundation
- [ ] Create unified repository interfaces
- [ ] Implement FirebaseItemRepository
- [ ] Create BaseItem protocol and concrete types
- [ ] Write comprehensive tests

### Week 2: Data Migration
- [ ] Implement migration service
- [ ] Run migration on test data
- [ ] Verify data integrity
- [ ] Deploy to staging environment

### Week 3: UI Updates
- [ ] Update SelectEntriesFlowViewController → SelectItemsFlowViewController
- [ ] Enhance collection view cells for mixed content
- [ ] Update category views with type filtering
- [ ] Test all user flows

### Week 4: Polish & Launch
- [ ] Implement enhanced features
- [ ] Performance optimization
- [ ] Complete testing
- [ ] Production deployment
- [ ] Monitor and iterate

## Success Metrics

### Technical Success
- [ ] Zero data loss during migration
- [ ] <100ms query performance for item fetching
- [ ] 100% backward compatibility maintained
- [ ] All existing tests pass

### User Experience Success  
- [ ] Select flow supports all item types
- [ ] No disruption to existing workflows
- [ ] Improved search across all content
- [ ] Consistent UI patterns

## Risk Mitigation

### Data Loss Prevention
- Complete backup before migration
- Incremental migration with validation
- Rollback plan tested and ready

### Performance Monitoring
- Query performance benchmarks
- Index optimization
- Cache warming strategies

### User Experience Continuity
- Feature flags for gradual rollout
- A/B testing for UI changes
- User feedback collection

---

*This plan provides a comprehensive approach to unifying the collections while maintaining data integrity and user experience. The phased approach allows for careful validation at each step.*