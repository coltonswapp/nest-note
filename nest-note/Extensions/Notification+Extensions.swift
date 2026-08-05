import UIKit

extension Notification.Name {
    static let userInformationUpdated = Notification.Name("userInformationUpdated")
    static let noteDidSave = Notification.Name("noteDidSave")
    static let placeDidSave = Notification.Name("placeDidSave")
    static let apnsTokenDidRegister = Notification.Name("apnsTokenDidRegister")
    static let apnsTokenRegistrationFailed = Notification.Name("apnsTokenRegistrationFailed")
    static let fcmTokenDidUpdate = Notification.Name("fcmTokenDidUpdate")
    static let adminSignupNotificationTapped = Notification.Name("adminSignupNotificationTapped")
}
