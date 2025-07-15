//
//  NNViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//
import UIKit

// MARK: - NNTippable Protocol
protocol NNTippable: AnyObject {
    func showTips()
    func trackScreenVisit(_ screenName: String?)
    func cleanupTips()
}

// Default implementations for NNTippable
extension NNTippable where Self: UIViewController {
    func trackScreenVisit(_ screenName: String? = nil) {
        let name = screenName ?? String(describing: type(of: self))
        NNTipManager.shared.trackScreenVisit(name)
    }
    
    func cleanupTips() {
        NNTipManager.shared.dismissAllActiveTips()
    }
}

class NNViewController: UIViewController {

    override func loadView() {
        super.loadView()
        view.backgroundColor = .systemBackground
        basicSetup()
        setup()
        setupNavigationBarButtons()
    }
    
    func basicSetup() {
        addSubviews()
        constrainSubviews()
    }
    
    func setup() {
        // Default empty implementation
        // Subclasses can override this if needed
    }
    
    func setupNavigationBarButtons() {
        // Default empty implementation
        // Subclasses can override this if needed
    }
    
    func addSubviews() {
        // Default empty implementation
        // Subclasses can override this if needed
    }
    
    func constrainSubviews() {
        // Default empty implementation
        // Subclasses can override this if needed
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Only call showTips for view controllers that implement NNTippable
        if self is NNTippable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                (self as? NNTippable)?.showTips()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Only cleanup tips for view controllers that implement NNTippable
        if let tippableVC = self as? NNTippable {
            tippableVC.cleanupTips()
        }
    }
    
    @objc func closeButtonTapped() {
        self.dismiss(animated: true)
    }
}
