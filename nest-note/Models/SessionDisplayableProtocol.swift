import Foundation

/// Protocol that both SessionItem and ArchivedSession conform to
/// This allows them to be displayed in the same collection view
protocol SessionDisplayable: Identifiable, Hashable {
    var id: String { get }
    var title: String { get }
    var startDate: Date { get }
    var endDate: Date { get }
    var status: SessionStatus { get }
    var assignedSitter: AssignedSitter? { get }
    var nestID: String { get }
    var ownerID: String? { get }
    var visibilityLevel: VisibilityLevel { get }
}
