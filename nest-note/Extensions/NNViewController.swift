//
//  NNViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//
import UIKit

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showTips()
        }
    }
    
    @objc func closeButtonTapped() {
        self.dismiss(animated: true)
    }
    
    func showTips() {
        // Default empty implementation
        // Subclasses can override this if needed
    }
}
