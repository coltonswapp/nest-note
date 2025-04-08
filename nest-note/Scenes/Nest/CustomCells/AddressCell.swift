//
//  AddressCell.swift
//  nest-note
//
//  Created by Colton Swapp on 11/12/24.
//
import UIKit

protocol AddressCellDelegate: AnyObject {
    func addressCell(_ cell: AddressCell, didTapAddress address: String)
}

class AddressCell: UICollectionViewCell {
    static let reuseIdentifier = "AddressCell"
    
    weak var delegate: AddressCellDelegate?
    
    private let addressLabel = UILabel()
    
    private var currentAddress: String?
    
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
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(addressTapped))
        addressLabel.addGestureRecognizer(tapGesture)
    }
    
    func configure(address: String) {
        currentAddress = address
        // Set the text with underline
        let attributedString = NSAttributedString(string: address, attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.label
        ])
        addressLabel.attributedText = attributedString
    }
    
    @objc private func addressTapped() {
        guard let address = currentAddress else { return }
        delegate?.addressCell(self, didTapAddress: address)
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.contentView.backgroundColor = self.isHighlighted ? .systemGray4 : .clear
            }
        }
    }
}
