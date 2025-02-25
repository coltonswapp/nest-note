import UIKit

extension UIImage {
    var averageColor: UIColor? {
        // Resize image to 1x1 pixel
        let size = CGSize(width: 1, height: 1)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: 1)
        
        guard let pixel = UIGraphicsGetImageFromCurrentImageContext()?.cgImage,
              let data = pixel.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }
        
        // Get components assuming RGBA format
        let r = CGFloat(bytes[0]) / 255
        let g = CGFloat(bytes[1]) / 255
        let b = CGFloat(bytes[2]) / 255
        
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }
} 