//
//  AddressCell.swift
//  nest-note
//
//  Created by Colton Swapp on 11/12/24.
//
import UIKit

class AddressCell: UICollectionViewCell {
    static let reuseIdentifier = "AddressCell"
    
    private let addressLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(addressLabel)
        
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            addressLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            addressLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            addressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            addressLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])

        addressLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        addressLabel.textColor = .label
        addressLabel.numberOfLines = 0
        addressLabel.textAlignment = .left
        
        // Add underline
        addressLabel.attributedText = NSAttributedString(string: "", attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        
        // Enable user interaction
        addressLabel.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(addressLabelTapped))
        addressLabel.addGestureRecognizer(tapGesture)
    }
    
    func configure(address: String) {
        // Set the text with underline
        let attributedString = NSAttributedString(string: address, attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.label
        ])
        addressLabel.attributedText = attributedString
    }
    
    @objc private func addressLabelTapped() {
        UIPasteboard.general.string = addressLabel.text
        
        // Provide feedback to the user
        HapticsHelper.lightHaptic()
        
        // Optionally, you can show a temporary label or use any other UI to indicate successful copying
        // For example:
        let copiedLabel = UILabel()
        copiedLabel.text = "Copied!"
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        copiedLabel.textAlignment = .center
        copiedLabel.layer.cornerRadius = 10
        copiedLabel.clipsToBounds = true
        
        contentView.addSubview(copiedLabel)
        copiedLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            copiedLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            copiedLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            copiedLabel.widthAnchor.constraint(equalToConstant: 100),
            copiedLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
            copiedLabel.alpha = 0
        }) { _ in
            copiedLabel.removeFromSuperview()
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.contentView.backgroundColor = self.isHighlighted ? .systemGray4 : .clear
            }
        }
    }
}
