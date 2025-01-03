import UIKit

class InviteSitterCell: UICollectionViewListCell {
    static let reuseIdentifier = "InviteSitterCell"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Configure the content view
        var bgConfig = UIBackgroundConfiguration.listGroupedCell()
        bgConfig.backgroundColor = .secondarySystemGroupedBackground
        backgroundConfiguration = bgConfig
    }
    
    func configure(name: String, email: String, isSelected: Bool = false) {
        // Get default content configuration
        var content = defaultContentConfiguration()
        
        // Configure text style
        content.text = name
        content.textProperties.font = .systemFont(ofSize: 16, weight: .medium)
        
        content.secondaryText = email
        content.secondaryTextProperties.font = .systemFont(ofSize: 14)
        content.secondaryTextProperties.color = .secondaryLabel
        
        // Apply standard system margins
        content.directionalLayoutMargins = .init(top: 12, leading: 16, bottom: 12, trailing: 16)
        
        // Update the content configuration
        contentConfiguration = content
        
        // Add checkmark accessory for selected state
        if isSelected {
            let checkmark = UICellAccessory.CustomViewConfiguration(
                customView: UIImageView(image: UIImage(systemName: "checkmark")?
                    .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)),
                placement: .trailing()
            )
            accessories = [.customView(configuration: checkmark)]
        } else {
            accessories = []
        }
    }
} 
