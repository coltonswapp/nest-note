import UIKit

extension UICollectionViewCell {
    /// Shows a "Copied!" feedback overlay with haptic feedback
    /// - Parameters:
    ///   - text: The text to display (defaults to "Copied!")
    ///   - duration: How long to show the feedback (defaults to 1.0)
    ///   - width: Width of the feedback label (defaults to 100)
    ///   - height: Height of the feedback label (defaults to 40)
    func showCopyFeedback(
        text: String = "Copied!",
        duration: TimeInterval = 1.0,
        width: CGFloat = 100,
        height: CGFloat = 40
    ) {
        HapticsHelper.lightHaptic()
        
        let copiedLabel = UILabel()
        copiedLabel.text = text
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        copiedLabel.textAlignment = .center
        copiedLabel.layer.cornerRadius = 10
        copiedLabel.clipsToBounds = true
        copiedLabel.alpha = 0
        
        contentView.addSubview(copiedLabel)
        copiedLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            copiedLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            copiedLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            copiedLabel.widthAnchor.constraint(equalToConstant: width),
            copiedLabel.heightAnchor.constraint(equalToConstant: height)
        ])
        
        UIView.animate(withDuration: 0.2) {
            copiedLabel.alpha = 1
        }
        
        UIView.animate(withDuration: 0.5, delay: duration, options: [], animations: {
            copiedLabel.alpha = 0
        }) { _ in
            copiedLabel.removeFromSuperview()
        }
    }
} 