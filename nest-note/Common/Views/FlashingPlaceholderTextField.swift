import UIKit

class FlashingPlaceholderTextField: UITextField {
    
    private var placeholders: [String] = []
    private var currentIndex = 0
    private var timer: Timer?
    
    private let fadeOutDuration: TimeInterval = 0.2
    private let fadeInDuration: TimeInterval = 0.3
    private let holdDuration: TimeInterval = 1.2
    
    var isAnimating: Bool = false {
        didSet {
            if isAnimating {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }
    
    init(placeholders: [String]) {
        super.init(frame: .zero)
        self.placeholders = placeholders
        self.placeholder = placeholders.first
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func startAnimating() {
        guard timer == nil else { return }
        
        // Start with first placeholder
        currentIndex = 0
        placeholder = placeholders[currentIndex]
        
        // Create and schedule timer
        timer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: true) { [weak self] _ in
            self?.animateNextPlaceholder()
        }
    }
    
    private func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }
    
    private func animateNextPlaceholder() {
        // Fade out current placeholder
        UIView.animate(withDuration: fadeOutDuration, animations: {
            self.alpha = 0
        }, completion: { _ in
            // Update to next placeholder
            self.currentIndex = (self.currentIndex + 1) % self.placeholders.count
            self.placeholder = self.placeholders[self.currentIndex]
            
            // Fade in new placeholder
            UIView.animate(withDuration: self.fadeInDuration) {
                self.alpha = 1
            }
        })
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if text?.isEmpty ?? true {
            isAnimating = true
        }
    }
    
    // Stop animation when text field becomes first responder
    override func becomeFirstResponder() -> Bool {
        return super.becomeFirstResponder()
    }
    
    // Resume animation when text field resigns first responder and has no text
    override func resignFirstResponder() -> Bool {
        if text?.isEmpty == true {
            isAnimating = true
        }
        return super.resignFirstResponder()
    }
    
    deinit {
        stopAnimating()
    }
} 
