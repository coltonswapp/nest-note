import UIKit

class ScrollingLabel: UILabel {
    var scrollSpeed: Double = 30.0 // Points per second
    var pauseTime: Double = 1.5  // Pause at beginning and end
    
    private var textWidth: CGFloat {
        return (text as? NSString)?.size(withAttributes: [.font: font!]).width ?? 0
    }
    
    func startScrolling() {
        // Only scroll if text exceeds label width
        guard textWidth > bounds.width else { return }
        
        // Reset position
        self.transform = .identity
        
        UIView.animate(withDuration: pauseTime, delay: 0, options: [], animations: {
            // Do nothing - just pause
        }, completion: { _ in
            self.scroll()
        })
    }
    
    private func scroll() {
        let distance = textWidth - bounds.width
        let duration = Double(distance) / scrollSpeed
        
        UIView.animate(withDuration: duration, delay: 0, options: [.curveLinear], animations: {
            self.transform = CGAffineTransform(translationX: -distance, y: 0)
        }, completion: { _ in
            UIView.animate(withDuration: self.pauseTime, delay: 0, options: [], animations: {
                // Pause at end
            }, completion: { _ in
                // Reset and restart
                self.transform = .identity
                self.startScrolling()
            })
        })
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            startScrolling()
        }
    }
} 