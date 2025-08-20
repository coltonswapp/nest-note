import UIKit

extension UIFont {
    /// Returns a rounded variant of the font using SF Rounded design
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    /// Creates a system font with rounded design
    static func systemRounded(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        return systemFont.rounded()
    }
    
    /// Creates a bold system font with rounded design
    static func boldSystemRounded(ofSize size: CGFloat) -> UIFont {
        return systemRounded(ofSize: size, weight: .bold)
    }
    
    /// Creates a semibold system font with rounded design
    static func semiboldSystemRounded(ofSize size: CGFloat) -> UIFont {
        return systemRounded(ofSize: size, weight: .semibold)
    }
    
    /// Creates a medium system font with rounded design
    static func mediumSystemRounded(ofSize size: CGFloat) -> UIFont {
        return systemRounded(ofSize: size, weight: .medium)
    }
    
    // MARK: - Design System Typography
    
    // MARK: Headings
    /// 24pt, bold
    static var h1: UIFont {
        return .systemFont(ofSize: 24, weight: .bold).rounded()
    }
    /// 20pt, bold
    static var h2: UIFont {
        return .systemFont(ofSize: 20, weight: .bold).rounded()
    }
    /// 18pt, bold
    static var h3: UIFont {
        return .systemFont(ofSize: 18, weight: .bold)
    }
    /// 16pt, semibold
    static var h4: UIFont {
        return .systemFont(ofSize: 16, weight: .semibold)
    }
    /// 14pt, bold
    static var h5: UIFont {
        return .systemFont(ofSize: 14, weight: .bold)
    }
    
    // MARK: Body
    /// 18pt, med
    static var bodyXL: UIFont {
        return .systemFont(ofSize: 18, weight: .medium)
    }
    /// 16pt, reg
    static var bodyL: UIFont {
        return .systemFont(ofSize: 16)
    }
    /// 14pt, reg
    static var bodyM: UIFont {
        return .systemFont(ofSize: 14)
    }
    /// 12pt, reg
    static var bodyS: UIFont {
        return .systemFont(ofSize: 12)
    }
    
    // MARK: Caption
    /// 14pt, semibold
    static var captionBoldM: UIFont {
        return .systemFont(ofSize: 14, weight: .semibold)
    }
    
    /// 12pt, semibold
    static var captionBoldS: UIFont {
        return .systemFont(ofSize: 12, weight: .semibold)
    }
} 
