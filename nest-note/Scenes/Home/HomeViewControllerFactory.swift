import UIKit

enum HomeViewControllerFactory {
    /// Creates and returns the appropriate home view controller based on the user's role
    static func createHomeViewController() -> UIViewController {
        // Get the user's role from NestService
        if NestService.shared.isOwner {
            let ownerVC = OwnerHomeViewController()
            return UINavigationController(rootViewController: ownerVC)
        } else {
            let sitterVC = SitterHomeViewController()
            return UINavigationController(rootViewController: sitterVC)
        }
    }
    
    /// Creates and returns the appropriate home view controller embedded in a navigation controller
    static func createHomeNavigationController() -> UINavigationController {
        // Get the user's role from NestService
        if NestService.shared.isOwner {
            let ownerVC = OwnerHomeViewController()
            return UINavigationController(rootViewController: ownerVC)
        } else {
            let sitterVC = SitterHomeViewController()
            return UINavigationController(rootViewController: sitterVC)
        }
    }
} 