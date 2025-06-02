import UIKit

class InviteSitterCell: UICollectionViewListCell {
    static let reuseIdentifier = "InviteSitterCell"
    
    func configure(name: String, email: String, isSelected: Bool = false) {
        
        // Get default content configuration
        var content = defaultContentConfiguration()
        
        // Configure text style
        content.text = name
        content.textProperties.font = .h4
        
        content.secondaryText = email
        content.secondaryTextProperties.font = .bodyM
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
