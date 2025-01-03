//
// NameOnboardingViewController.swift
// nest-note
//
// Created by Colton Swapp on 11/3/24.
//

import UIKit

class NameOnboardingViewController: NNOnboardingViewController {
    
    private let nameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Full Name"
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .systemGray6
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupOnboarding(
            title: "First, let's get your name",
            subtitle: "Don't worry, this is for display purposes only."
        )
        setupContent()
        addCTAButton(title: "Next", image: UIImage(systemName: "arrow.right"))
    }
    
    override func setupContent() {
        view.addSubview(nameTextField)
        
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            nameTextField.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
} 
