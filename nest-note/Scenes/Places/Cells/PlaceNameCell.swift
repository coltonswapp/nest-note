import UIKit

protocol PlaceNameCellDelegate: AnyObject {
    func placeNameCell(_ cell: PlaceNameCell, didUpdateAlias alias: String)
}

final class PlaceNameCell: UICollectionViewListCell {
    weak var delegate: PlaceNameCellDelegate?
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
        imageView.image = UIImage(systemName: "mappin.and.ellipse", withConfiguration: symbolConfig)
        return imageView
    }()
    
    private let aliasTextField: FlashingPlaceholderTextField = {
        let placeholders = [
            "Cello Lesson",
            "Soccer Practice",
            "Rolling Hills Elementary",
            "Grandma's House",
            "Isabelle Dance"
        ]
        let field = FlashingPlaceholderTextField(placeholders: placeholders)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = .bodyL
        field.returnKeyType = .done
        return field
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(aliasTextField)
        
        aliasTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        aliasTextField.delegate = self
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            aliasTextField.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            aliasTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            aliasTextField.heightAnchor.constraint(equalToConstant: 48),
            
            aliasTextField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            aliasTextField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }
    
    @objc private func textFieldDidChange() {
        delegate?.placeNameCell(self, didUpdateAlias: aliasTextField.text ?? "")
    }
    
    func configure(with item: PlaceDetailViewController.Item) {
        if case let .name(alias) = item {
            // Set the initial text
            aliasTextField.text = alias
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.aliasTextField.isAnimating = self.aliasTextField.text?.isEmpty ?? true
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension PlaceNameCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
} 
