//
//  QRCodeViewController.swift
//  nest-note
//
//  Created by Claude on 8/20/25.
//

import UIKit
import QRCode

class QRCodeViewController: UIViewController {
    
    private let inviteCode: String
    private var qrCodeImageView: UIImageView!
    private var instructionLabel: UILabel!
    
    init(inviteCode: String) {
        self.inviteCode = inviteCode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        generateQRCode()
    }
    
    private func setupView() {
        view.backgroundColor = .systemBackground
        title = "Scan QR Code"
        
        // Navigation bar setup
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
        
        // QR Code image view
        qrCodeImageView = UIImageView()
        qrCodeImageView.contentMode = .scaleAspectFit
        qrCodeImageView.backgroundColor = .white
        qrCodeImageView.layer.cornerRadius = 16
        qrCodeImageView.clipsToBounds = true
        qrCodeImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Instruction label
        instructionLabel = UILabel()
        instructionLabel.text = "Show this QR code to your sitter."
        instructionLabel.font = .bodyL
        instructionLabel.textColor = .secondaryLabel
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        view.addSubview(qrCodeImageView)
        view.addSubview(instructionLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            
            qrCodeImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            qrCodeImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            qrCodeImageView.widthAnchor.constraint(equalToConstant: view.frame.width * 0.7),
            qrCodeImageView.heightAnchor.constraint(equalToConstant: view.frame.width * 0.7),
            
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }
    
    private func generateQRCode() {
        let inviteURL = "nestnote://invite?code=\(inviteCode)"
        
        do {
            let doc = try QRCode.Document(utf8String: inviteURL)
            
            // Configure the QR code design with the specified settings
            doc.design.shape.eye = QRCode.EyeShape.Squircle()
            doc.design.shape.pupil = QRCode.PupilShape.Circle()
            
            // Generate the QR code image
            let cgImage = try doc.cgImage(CGSize(width: 512, height: 512))
            qrCodeImageView.image = UIImage(cgImage: cgImage)
            
        } catch {
            print("Error generating QR code: \(error)")
            // Fallback: show error message
            let label = UILabel()
            label.text = "Error generating QR code"
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            qrCodeImageView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: qrCodeImageView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: qrCodeImageView.centerYAnchor)
            ])
        }
    }
    
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
}
