import UIKit

extension Notification.Name {
    static let userInformationUpdated = Notification.Name("userInformationUpdated")
    static let noteDidSave = Notification.Name("noteDidSave")
    static let placeDidSave = Notification.Name("placeDidSave")
    /// Posted after a place's map thumbnails finish uploading in the background.
    static let placeThumbnailsDidUpdate = Notification.Name("placeThumbnailsDidUpdate")
    static let pinnedCategoriesDidChange = Notification.Name("pinnedCategoriesDidChange")
    /// Posted after a nest folder/category is created or deleted so other nest screens can refresh.
    static let nestCategoryDidChange = Notification.Name("nestCategoryDidChange")
    static let apnsTokenDidRegister = Notification.Name("apnsTokenDidRegister")
    static let apnsTokenRegistrationFailed = Notification.Name("apnsTokenRegistrationFailed")
    static let fcmTokenDidUpdate = Notification.Name("fcmTokenDidUpdate")
    static let adminSignupNotificationTapped = Notification.Name("adminSignupNotificationTapped")
    /// Posted after Firebase Remote Config fetch/activate completes.
    static let featureFlagsDidUpdate = Notification.Name("featureFlagsDidUpdate")
    /// Posted after entering or exiting influencer demo mode.
    static let demoModeDidChange = Notification.Name("demoModeDidChange")
}
