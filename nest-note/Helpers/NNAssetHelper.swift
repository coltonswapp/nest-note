import UIKit

enum NNAssetType: String {
    case rectanglePattern = "rectangle_pattern"
    case halfMoonTop = "half_moon_top"
    case halfMoonTest = "half-moon-test"
    case halfMoonBottom = "half_moon_bottom"
    case rectanglePatternSmall = "rectangle_pattern_small"
    
    var heightMultiplier: CGFloat {
        switch self {
        case .rectanglePattern:
            return 0.27
        case .rectanglePatternSmall:
            return 0.15
        case .halfMoonTop, .halfMoonTest:
            return 0.56
        case .halfMoonBottom:
            return 0.56
        }
    }
    
    var defaultAlpha: CGFloat {
        switch self {
        case .rectanglePattern:
            return 0.4
        case .halfMoonTop, .halfMoonBottom, .halfMoonTest:
            return 1.0
        case .rectanglePatternSmall:
            return 0.8
        }
    }
    
    var contentMode: UIView.ContentMode {
        switch self {
        case .rectanglePattern, .rectanglePatternSmall, .halfMoonTop, .halfMoonBottom, .halfMoonTest:
            return .scaleAspectFill
        }
    }
    
    var tintColor: UIColor? {
        switch self {
        case .rectanglePatternSmall:
            return NNColors.EventColors.coreFour.randomElement()?.border
        default:
            return nil
        }
    }
}

class NNAssetHelper {
    static func configureImageView(_ imageView: UIImageView, for assetType: NNAssetType, with tint: UIColor? = nil) {
        imageView.image = UIImage(named: assetType.rawValue)
        imageView.contentMode = assetType.contentMode
        imageView.alpha = assetType.defaultAlpha
        imageView.image?.accessibilityIdentifier = assetType.rawValue
        imageView.tintColor = tint ?? assetType.tintColor
    }
    
    static func constrainImageView(_ imageView: UIImageView, in view: UIView, to edge: UIRectEdge = .top) {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: view.frame.width * assetType(for: imageView).heightMultiplier)
        ])
        
        if edge == .top {
            imageView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        } else if edge == .bottom {
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        }
    }
    
    private static func assetType(for imageView: UIImageView) -> NNAssetType {
        guard let imageName = imageView.image?.accessibilityIdentifier,
              let assetType = NNAssetType(rawValue: imageName) else {
            // Default to rectangle pattern if we can't determine the type
            return .rectanglePattern
        }
        return assetType
    }
}

// MARK: - UIImageView Extension
extension UIImageView {
    func configureForAsset(_ assetType: NNAssetType) {
        NNAssetHelper.configureImageView(self, for: assetType)
    }
    
    func pinToTop(of view: UIView) {
        NNAssetHelper.constrainImageView(self, in: view)
    }
    
    func pinToBottom(of view: UIView) {
        NNAssetHelper.constrainImageView(self, in: view, to: .bottom)
    }
}
