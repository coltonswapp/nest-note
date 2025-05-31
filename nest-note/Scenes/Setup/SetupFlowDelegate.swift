import Foundation

protocol SetupFlowDelegate: AnyObject {
    // Called when the user completes the entire setup flow
    func setupFlowDidComplete()
    
    // Called when a specific step's status changes
    func setupFlowDidUpdateStepStatus()
} 