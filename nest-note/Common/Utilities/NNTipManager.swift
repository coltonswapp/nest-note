import UIKit
import TipKit

// MARK: - Tip Definitions
struct EntryTitleContentTip: Tip {
    var title: Text {
        Text("Title and Content")
    }
    
    var message: Text? {
        Text("Entries are made up of a title and content. Both are required.")
    }
    
    var image: Image? {
        Image(systemName: "doc.text")
    }
}

struct EntryDetailsTip: Tip {
    var title: Text {
        Text("Tap here for more details")
    }
    
    var message: Text? {
        Text("More details about your entry are located here")
    }
    
    var image: Image? {
        Image(systemName: "ellipsis.circle")
    }
}

struct VisibilityLevelTip: Tip {
    var title: Text {
        Text("Tap here to change visibility level")
    }
    
    var message: Text? {
        Text("Changing the visibility level is easy")
    }
    
    var image: Image? {
        Image(systemName: "eye")
    }
}

// MARK: - Tip Groups (Manual Sequential Implementation)
struct EntryDetailTipGroup {
    let tips: [any Tip] = [
        EntryTitleContentTip(),
        EntryDetailsTip(),
        VisibilityLevelTip()
    ]
}

// MARK: - TipKit UIKit Wrapper
class NNTipManager {
    static let shared = NNTipManager()
    
    private init() {}
    
    // Keep track of active tip views and their observation tasks
    private var activeTipViews: [UIView] = []
    private var tipObservationTasks: [String: Task<Void, Never>] = [:]
    private var sequentialTipTasks: [String: Task<Void, Never>] = [:]
    
    // Configure TipKit
    func configure() {
        print("🔧 [TipKit Debug] Configuring TipKit...")
        do {
            try Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
            print("✅ [TipKit Debug] TipKit configured successfully")
        } catch {
            print("❌ [TipKit Debug] Failed to configure TipKit: \(error)")
        }
    }
    
    // Reset all tips (for testing)
    func resetAllTips() {
        print("🔄 [TipKit Debug] Resetting all tips datastore...")
        do {
            try Tips.resetDatastore()
            print("✅ [TipKit Debug] Datastore reset successful")
            
            // Reconfigure TipKit after reset
            print("🔧 [TipKit Debug] Reconfiguring TipKit after reset...")
            configure()
        } catch {
            print("❌ [TipKit Debug] Failed to reset datastore: \(error)")
            print("⚠️ [TipKit Debug] TipKit datastore can only be reset before configuration.")
            print("⚠️ [TipKit Debug] For development, restart the app to see tips again.")
            
            // Show helpful message for developer
            showDeveloperResetMessage()
        }
    }
    
    // Show developer message when reset fails
    private func showDeveloperResetMessage() {
        print("💡 [TipKit Debug] Developer Tip: To reset tips during development:")
        print("   1. Stop the app completely")
        print("   2. Delete the app from device/simulator")
        print("   3. Reinstall and run again")
        print("   OR")
        print("   1. Call Tips.resetDatastore() BEFORE Tips.configure()")
        print("   2. This means calling it before app launch or in a fresh app state")
    }
    
    // Show tip for a specific view
    func showTip<T: Tip>(_ tip: T, for view: UIView, in viewController: UIViewController) {
        let tipView = TipUIView(tip, arrowEdge: .top)
        tipView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add tip view to the view controller's view
        viewController.view.addSubview(tipView)
        
        // Position the tip relative to the target view
        NSLayoutConstraint.activate([
            tipView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tipView.topAnchor.constraint(equalTo: view.bottomAnchor, constant: 8),
            tipView.leadingAnchor.constraint(greaterThanOrEqualTo: viewController.view.leadingAnchor, constant: 16),
            tipView.trailingAnchor.constraint(lessThanOrEqualTo: viewController.view.trailingAnchor, constant: -16)
        ])
        
        // Auto-hide after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            tipView.removeFromSuperview()
        }
    }
    
    // Simpler method for showing tips with custom positioning
    func showTip<T: Tip>(_ tip: T, 
                        sourceView: UIView, 
                        in viewController: UIViewController,
                        arrowEdge: Edge = .top,
                        offset: CGPoint = CGPoint(x: 0, y: 8)) {
        
        let tipView = TipUIView(tip, arrowEdge: arrowEdge)
        tipView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up dismiss handler for the X button
        let dismissAction = UIAction { _ in
            self.dismissTipWithAnimation(tipView)
        }
        
        // Add to active tips tracking
        activeTipViews.append(tipView)
        
        // Find and configure the dismiss button (try immediately and after delay)
//        if let dismissButton = findDismissButton(in: tipView) {
//            dismissButton.addAction(dismissAction, for: .touchUpInside)
//            print("✅ Successfully configured dismiss button")
//        } else {
//            // Try again after a short delay in case the view isn't fully constructed
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                if let dismissButton = self.findDismissButton(in: tipView) {
//                    dismissButton.addAction(dismissAction, for: .touchUpInside)
//                    print("✅ Successfully configured dismiss button (delayed)")
//                } else {
//                    print("❌ Could not find dismiss button, adding fallback")
//                    // Add a fallback: double-tap to dismiss
//                    let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleDoubleTap(_:)))
//                    doubleTapGesture.numberOfTapsRequired = 2
//                    tipView.addGestureRecognizer(doubleTapGesture)
//                }
//            }
//        }
        
        viewController.view.addSubview(tipView)
        
        var constraints: [NSLayoutConstraint] = []
        
        switch arrowEdge {
        case .top:
            constraints = [
                tipView.centerXAnchor.constraint(equalTo: sourceView.centerXAnchor, constant: offset.x),
                tipView.topAnchor.constraint(equalTo: sourceView.bottomAnchor, constant: offset.y)
            ]
        case .bottom:
            constraints = [
                tipView.centerXAnchor.constraint(equalTo: sourceView.centerXAnchor, constant: offset.x),
                tipView.bottomAnchor.constraint(equalTo: sourceView.topAnchor, constant: -offset.y)
            ]
        case .leading:
            constraints = [
                tipView.leadingAnchor.constraint(equalTo: sourceView.trailingAnchor, constant: offset.x),
                tipView.centerYAnchor.constraint(equalTo: sourceView.centerYAnchor, constant: offset.y)
            ]
        case .trailing:
            constraints = [
                tipView.trailingAnchor.constraint(equalTo: sourceView.leadingAnchor, constant: -offset.x),
                tipView.centerYAnchor.constraint(equalTo: sourceView.centerYAnchor, constant: offset.y)
            ]
        }
        
        // Add boundary constraints
        constraints.append(contentsOf: [
            tipView.leadingAnchor.constraint(greaterThanOrEqualTo: viewController.view.leadingAnchor, constant: 16),
            tipView.trailingAnchor.constraint(lessThanOrEqualTo: viewController.view.trailingAnchor, constant: -16),
            tipView.topAnchor.constraint(greaterThanOrEqualTo: viewController.view.safeAreaLayoutGuide.topAnchor, constant: 8),
            tipView.bottomAnchor.constraint(lessThanOrEqualTo: viewController.view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
        
        NSLayoutConstraint.activate(constraints)
        
        // Animate tip appearance
        showTipWithAnimation(tipView)
    }
    
    // MARK: - Animation Methods
    
    func showTipWithAnimation(_ tipView: UIView) {
        // Start with scale 0
        tipView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        tipView.alpha = 0.0
        
        // Animate to full scale
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseOut]) {
            tipView.transform = CGAffineTransform.identity
            tipView.alpha = 1.0
        }
    }
    
    private func dismissTipWithAnimation(_ tipView: UIView) {
        // Remove from active tips tracking
        if let index = activeTipViews.firstIndex(of: tipView) {
            activeTipViews.remove(at: index)
        }
        
        // Animate to scale 0 and fade out
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: [.curveEaseIn]) {
            tipView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            tipView.alpha = 0.0
        } completion: { _ in
            tipView.removeFromSuperview()
            
            // Call the dismissal continuation if it exists
            if let continuation = objc_getAssociatedObject(tipView, &AssociatedKeys.dismissalContinuation) as? CheckedContinuation<Void, Never> {
                continuation.resume()
            }
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if let tipView = gesture.view {
            // Properly invalidate the tip so TipKit knows it's been dismissed
            if let tip = objc_getAssociatedObject(tipView, &AssociatedKeys.tipReference) as? (any Tip) {
                tip.invalidate(reason: .tipClosed)
                print("✅ Tip invalidated through TipKit (double-tap)")
            }
            
            // Call the dismiss callback if it exists
            if let dismissCallback = objc_getAssociatedObject(tipView, &AssociatedKeys.dismissCallback) as? () -> Void {
                dismissCallback()
            }
            dismissTipWithAnimation(tipView)
        }
    }
    
    @objc private func handleTipDismiss(_ gesture: UITapGestureRecognizer) {
        if let dismissButton = gesture.view {
            // Find the tip view that contains this dismiss button
            var tipView: UIView?
            var currentView = dismissButton.superview
            while currentView != nil {
                if currentView is TipUIView {
                    tipView = currentView
                    break
                }
                currentView = currentView?.superview
            }
            
            if let tipView = tipView {
                // Properly invalidate the tip so TipKit knows it's been dismissed
                if let tip = objc_getAssociatedObject(dismissButton, &AssociatedKeys.tipReference) as? (any Tip) {
                    tip.invalidate(reason: .tipClosed)
                    print("✅ Tip invalidated through TipKit (gesture)")
                }
                
                // Call the dismiss callback if it exists
                if let dismissCallback = objc_getAssociatedObject(dismissButton, &AssociatedKeys.dismissCallback) as? () -> Void {
                    dismissCallback()
                }
                dismissTipWithAnimation(tipView)
            }
        }
    }
    
    // Method to dismiss all active tips
    func dismissAllActiveTips() {
        for tipView in activeTipViews {
            dismissTipWithAnimation(tipView)
        }
    }
    
    // MARK: - Automatic Tip Observation
    
    /// Automatically observes a tip's eligibility and shows/hides it accordingly
    /// - Parameters:
    ///   - tip: The tip to observe
    ///   - sourceView: The view to anchor the tip to
    ///   - viewController: The view controller to show the tip in
    ///   - arrowEdge: The edge for the tip arrow
    ///   - offset: The offset from the source view
    ///   - tipId: Unique identifier for this tip observation
    func observeTip<T: Tip>(_ tip: T,
                           sourceView: UIView,
                           in viewController: UIViewController,
                           arrowEdge: Edge = .top,
                           offset: CGPoint = CGPoint(x: 0, y: 8),
                           tipId: String) {
        
        // Cancel any existing observation for this tip
        stopObservingTip(tipId: tipId)
        
        // Start new observation
        let observationTask = Task { @MainActor in
            var currentTipView: UIView?
            
            print("🔍 [TipKit Debug] Starting observation for tip: \(tipId)")
            
            for await shouldDisplay in tip.shouldDisplayUpdates {
                print("🔍 [TipKit Debug] Tip \(tipId) shouldDisplay: \(shouldDisplay)")
                
                if shouldDisplay {
                    // Show tip if not already showing
                    if currentTipView == nil {
                        print("✅ [TipKit Debug] Showing tip: \(tipId)")
                        let tipView = TipUIView(tip, arrowEdge: arrowEdge)
                        tipView.translatesAutoresizingMaskIntoConstraints = false
                        
                        // Store tip reference for proper invalidation
                        objc_setAssociatedObject(tipView, &AssociatedKeys.tipReference, tip, .OBJC_ASSOCIATION_RETAIN)
                        
                        // Configure dismiss button
                        self.configureDismissButton(for: tipView, tipId: tipId)
                        
                        // Add to view hierarchy
                        viewController.view.addSubview(tipView)
                        
                        // Set up constraints
                        self.setupConstraints(for: tipView, sourceView: sourceView, viewController: viewController, arrowEdge: arrowEdge, offset: offset)
                        
                        // Animate in
                        self.showTipWithAnimation(tipView)
                        
                        // Track this tip
                        self.activeTipViews.append(tipView)
                        currentTipView = tipView
                        print("✅ [TipKit Debug] Tip \(tipId) displayed successfully")
                    } else {
                        print("⚠️ [TipKit Debug] Tip \(tipId) already showing, skipping")
                    }
                } else {
                    // Hide tip if currently showing
                    if let tipView = currentTipView {
                        print("❌ [TipKit Debug] Hiding tip: \(tipId)")
                        self.dismissTipWithAnimation(tipView)
                        currentTipView = nil
                    }
                }
            }
        }
        
        // Store the observation task
        tipObservationTasks[tipId] = observationTask
    }
    
    // MARK: - Tip Group Observation
    
    /// Observes a tip group and shows tips sequentially (one at a time)
    /// - Parameters:
    ///   - tipGroup: The tip group to observe
    ///   - tipConfigurations: Dictionary mapping tip types to their UI configurations
    ///   - viewController: The view controller to show the tips in
    ///   - groupId: Unique identifier for this tip group observation
    func observeTipGroup(_ tipGroup: EntryDetailTipGroup,
                        tipConfigurations: [String: (sourceView: UIView, arrowEdge: Edge, offset: CGPoint)],
                        in viewController: UIViewController,
                        groupId: String) {
        
        // Cancel any existing observation for this group
        stopObservingTipGroup(groupId: groupId)
        
        print("🔍 [TipKit Debug] Starting sequential tip group observation: \(groupId)")
        print("🔍 [TipKit Debug] Tip group has \(tipGroup.tips.count) tips")
        
        // Start sequential observation
        let sequentialTask = Task { @MainActor in
            for (index, tip) in tipGroup.tips.enumerated() {
                let tipTypeName = String(describing: type(of: tip))
                
                print("🔍 [TipKit Debug] Processing tip \(index): \(tipTypeName)")
                debugTipStatus(tip, name: tipTypeName)
                
                guard let config = tipConfigurations[tipTypeName] else {
                    print("⚠️ [TipKit Debug] No configuration found for tip type: \(tipTypeName)")
                    continue
                }
                
                // Wait for this tip to be eligible
                for await shouldDisplay in tip.shouldDisplayUpdates {
                    if shouldDisplay {
                        print("✅ [TipKit Debug] Showing sequential tip: \(tipTypeName)")
                        
                        // Show the tip
                        let tipView = TipUIView(tip, arrowEdge: config.arrowEdge)
                        tipView.translatesAutoresizingMaskIntoConstraints = false
                        
                        // Store tip reference for proper invalidation
                        objc_setAssociatedObject(tipView, &AssociatedKeys.tipReference, tip, .OBJC_ASSOCIATION_RETAIN)
                        
                        // Configure dismiss button with callback to proceed to next tip
                        await withCheckedContinuation { continuation in
                            configureDismissButton(for: tipView, tipId: "\(groupId)_\(tipTypeName)_\(index)") {
                                continuation.resume()
                            }
                            
                            // Add to view hierarchy
                            viewController.view.addSubview(tipView)
                            
                            // Set up constraints
                            setupConstraints(for: tipView, sourceView: config.sourceView, viewController: viewController, arrowEdge: config.arrowEdge, offset: config.offset)
                            
                            // Animate in
                            showTipWithAnimation(tipView)
                            
                            // Track this tip
                            activeTipViews.append(tipView)
                        }
                        
                        break // Exit the shouldDisplayUpdates loop for this tip
                    }
                }
                
                // Check if task was cancelled
                if Task.isCancelled {
                    print("🔍 [TipKit Debug] Sequential tip task cancelled")
                    break
                }
            }
        }
        
        // Store the sequential task
        tipObservationTasks[groupId] = sequentialTask
    }
    
    /// Stops observing a specific tip group
    /// - Parameter groupId: The unique identifier of the tip group to stop observing
    func stopObservingTipGroup(groupId: String) {
        // Find and cancel all tasks related to this group
        let groupTasks = tipObservationTasks.filter { $0.key.hasPrefix(groupId) }
        for (taskId, task) in groupTasks {
            task.cancel()
            tipObservationTasks.removeValue(forKey: taskId)
        }
    }
    
    /// Stops observing a tip
    /// - Parameter tipId: The unique identifier of the tip to stop observing
    func stopObservingTip(tipId: String) {
        tipObservationTasks[tipId]?.cancel()
        tipObservationTasks.removeValue(forKey: tipId)
    }
    
    /// Stops all tip observations (call this in viewWillDisappear)
    func stopAllTipObservations() {
        for (_, task) in tipObservationTasks {
            task.cancel()
        }
        tipObservationTasks.removeAll()
        
        for (_, task) in sequentialTipTasks {
            task.cancel()
        }
        sequentialTipTasks.removeAll()
    }
    
    // MARK: - Sequential Tip Display
    
    /// Shows tips in a specific order, one at a time
    /// - Parameters:
    ///   - tipConfigurations: Array of tip configurations in the order they should be shown
    ///   - viewController: The view controller to show the tips in
    ///   - sequenceId: Unique identifier for this tip sequence
    func observeTipsSequentially(_ tipConfigurations: [(tip: any Tip, sourceView: UIView, arrowEdge: Edge, offset: CGPoint, tipId: String)],
                                        in viewController: UIViewController,
                                        sequenceId: String) {
        
        // Cancel any existing sequence
        stopObservingSequence(sequenceId: sequenceId)
        
        // Start sequential observation
        let sequentialTask = Task { @MainActor in
            var currentIndex = 0
            
            while currentIndex < tipConfigurations.count {
                let config = tipConfigurations[currentIndex]
                
                // Wait for this tip to be eligible
                for await shouldDisplay in config.tip.shouldDisplayUpdates {
                    if shouldDisplay {
                        // Show current tip
                        let tipView = TipUIView(config.tip, arrowEdge: config.arrowEdge)
                        tipView.translatesAutoresizingMaskIntoConstraints = false
                        
                        // Store tip reference for proper invalidation
                        objc_setAssociatedObject(tipView, &AssociatedKeys.tipReference, config.tip, .OBJC_ASSOCIATION_RETAIN)
                        
                        // Configure dismiss button with callback to proceed to next tip
                        configureDismissButton(for: tipView, tipId: config.tipId) { [weak self] in
                            // Move to next tip when current one is dismissed
                            currentIndex += 1
                        }
                        
                        // Add to view hierarchy
                        viewController.view.addSubview(tipView)
                        
                        // Set up constraints
                        setupConstraints(for: tipView, sourceView: config.sourceView, viewController: viewController, arrowEdge: config.arrowEdge, offset: config.offset)
                        
                        // Animate in
                        showTipWithAnimation(tipView)
                        
                        // Track this tip
                        activeTipViews.append(tipView)
                        
                        // Wait for this tip to be dismissed before proceeding
                        await waitForTipDismissal(tipView)
                        break
                    }
                }
                
                // Check if task was cancelled
                if Task.isCancelled {
                    break
                }
            }
        }
        
        // Store the sequential task
        sequentialTipTasks[sequenceId] = sequentialTask
    }
    
    /// Stops observing a specific tip sequence
    /// - Parameter sequenceId: The unique identifier of the sequence to stop observing
    func stopObservingSequence(sequenceId: String) {
        sequentialTipTasks[sequenceId]?.cancel()
        sequentialTipTasks.removeValue(forKey: sequenceId)
    }
    
    /// Waits for a tip view to be dismissed
    private func waitForTipDismissal(_ tipView: UIView) async {
        // Use a continuation to wait for dismissal
//        await withCheckedContinuation { continuation in
//            // Store the continuation to be called when tip is dismissed
//            objc_setAssociatedObject(tipView, &AssociatedKeys.dismissalContinuation, continuation, .OBJC_ASSOCIATION_RETAIN)
//        }
    }
    
    private struct AssociatedKeys {
        static var dismissalContinuation = "dismissalContinuation"
        static var dismissCallback = "dismissCallback"
        static var tipReference = "tipReference"
    }
    
    // MARK: - Private Helper Methods
    
    func setupConstraints(for tipView: UIView, sourceView: UIView, viewController: UIViewController, arrowEdge: Edge, offset: CGPoint) {
        var constraints: [NSLayoutConstraint] = []
        
        switch arrowEdge {
        case .top:
            constraints = [
                tipView.centerXAnchor.constraint(equalTo: sourceView.centerXAnchor, constant: offset.x),
                tipView.topAnchor.constraint(equalTo: sourceView.bottomAnchor, constant: offset.y)
            ]
        case .bottom:
            constraints = [
                tipView.centerXAnchor.constraint(equalTo: sourceView.centerXAnchor, constant: offset.x),
                tipView.bottomAnchor.constraint(equalTo: sourceView.topAnchor, constant: -offset.y)
            ]
        case .leading:
            constraints = [
                tipView.leadingAnchor.constraint(equalTo: sourceView.trailingAnchor, constant: offset.x),
                tipView.centerYAnchor.constraint(equalTo: sourceView.centerYAnchor, constant: offset.y)
            ]
        case .trailing:
            constraints = [
                tipView.trailingAnchor.constraint(equalTo: sourceView.leadingAnchor, constant: -offset.x),
                tipView.centerYAnchor.constraint(equalTo: sourceView.centerYAnchor, constant: offset.y)
            ]
        }
        
        // Add boundary constraints
        constraints.append(contentsOf: [
            tipView.leadingAnchor.constraint(greaterThanOrEqualTo: viewController.view.leadingAnchor, constant: 16),
            tipView.trailingAnchor.constraint(lessThanOrEqualTo: viewController.view.trailingAnchor, constant: -16),
            tipView.topAnchor.constraint(greaterThanOrEqualTo: viewController.view.safeAreaLayoutGuide.topAnchor, constant: 8),
            tipView.bottomAnchor.constraint(lessThanOrEqualTo: viewController.view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
        
        NSLayoutConstraint.activate(constraints)
    }
    
    // Check if a tip should be shown
    func shouldShowTip<T: Tip>(_ tip: T) -> Bool {
        return tip.status == .available
    }
    
    // Mark a tip as completed
    func completeTip<T: Tip>(_ tip: T) {
        tip.invalidate(reason: .actionPerformed)
    }
    
    // Force show a tip (for testing)
    func forceShowTip<T: Tip>(_ tip: T) {
        tip.invalidate(reason: .displayCountExceeded)
    }
    
    // Debug tip status
    func debugTipStatus<T: Tip>(_ tip: T, name: String) {
        print("🔍 [TipKit Debug] \(name) - Status: \(tip.status)")
        
        // Add more detailed logging
        switch tip.status {
        case .available:
            print("✅ [TipKit Debug] \(name) - Available to show")
        case .invalidated(let reason):
            print("❌ [TipKit Debug] \(name) - Invalidated: \(reason)")
        case .pending:
            print("⏳ [TipKit Debug] \(name) - Pending")
        @unknown default:
            print("❓ [TipKit Debug] \(name) - Unknown status")
        }
    }
    
    // Force reset a tip to make it available again
    func resetTip<T: Tip>(_ tip: T) {
        // This doesn't actually reset the tip - invalidate marks it as dismissed
        // We need a different approach
    }
    
    // Alternative: check if tip should show OR force show for testing
    func shouldShowTipOrForce<T: Tip>(_ tip: T, forceShow: Bool = false) -> Bool {
        if forceShow {
            print("🔧 [TipKit Debug] Force showing tip: \(String(describing: type(of: tip)))")
            return true
        }
        return tip.status == .available
    }
    
    // Force show tips for development (bypasses TipKit status)
    func forceShowTipsForDevelopment() {
        print("🔧 [TipKit Debug] Force showing tips for development")
        // This will be used in development to bypass tip status
    }
}

// MARK: - Convenience Extensions
extension UIViewController {
    func showTip<T: Tip>(_ tip: T, for view: UIView, arrowEdge: Edge = .top, offset: CGPoint = CGPoint(x: 0, y: 8)) {
        NNTipManager.shared.showTip(tip, sourceView: view, in: self, arrowEdge: arrowEdge, offset: offset)
    }
    
    /// Automatically observes a tip and shows/hides it based on eligibility
    /// - Parameters:
    ///   - tip: The tip to observe
    ///   - view: The view to anchor the tip to
    ///   - arrowEdge: The edge for the tip arrow
    ///   - offset: The offset from the source view
    ///   - tipId: Unique identifier for this tip observation
    func observeTip<T: Tip>(_ tip: T, for view: UIView, arrowEdge: Edge = .top, offset: CGPoint = CGPoint(x: 0, y: 8), tipId: String) {
        NNTipManager.shared.observeTip(tip, sourceView: view, in: self, arrowEdge: arrowEdge, offset: offset, tipId: tipId)
    }
    
    /// Stops observing a specific tip
    /// - Parameter tipId: The unique identifier of the tip to stop observing
    func stopObservingTip(tipId: String) {
        NNTipManager.shared.stopObservingTip(tipId: tipId)
    }
    
    /// Stops all tip observations (call this in viewWillDisappear)
    func stopAllTipObservations() {
        NNTipManager.shared.stopAllTipObservations()
    }
    
    /// Shows tips in a specific order, one at a time
    /// - Parameters:
    ///   - tipConfigurations: Array of tip configurations in the order they should be shown
    ///   - sequenceId: Unique identifier for this tip sequence
    func observeTipsSequentially(_ tipConfigurations: [(tip: any Tip, sourceView: UIView, arrowEdge: Edge, offset: CGPoint, tipId: String)], sequenceId: String) {
        NNTipManager.shared.observeTipsSequentially(tipConfigurations, in: self, sequenceId: sequenceId)
    }
    
    /// Stops observing a specific tip sequence
    /// - Parameter sequenceId: The unique identifier of the sequence to stop observing
    func stopObservingSequence(sequenceId: String) {
        NNTipManager.shared.stopObservingSequence(sequenceId: sequenceId)
    }
    
    /// Observes a tip group and shows tips based on ordering
    /// - Parameters:
    ///   - tipGroup: The tip group to observe
    ///   - tipConfigurations: Dictionary mapping tip types to their UI configurations
    ///   - groupId: Unique identifier for this tip group observation
    func observeTipGroup(_ tipGroup: EntryDetailTipGroup,
                        tipConfigurations: [String: (sourceView: UIView, arrowEdge: Edge, offset: CGPoint)],
                        groupId: String) {
        NNTipManager.shared.observeTipGroup(tipGroup, tipConfigurations: tipConfigurations, in: self, groupId: groupId)
    }
    
    /// Stops observing a specific tip group
    /// - Parameter groupId: The unique identifier of the tip group to stop observing
    func stopObservingTipGroup(groupId: String) {
        NNTipManager.shared.stopObservingTipGroup(groupId: groupId)
    }
}
