//
//  LoadingViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 5/1/25.
//
import UIKit

class LoadingViewController: UIViewController {
    private let birdImageView: UIImageView = {
        let imageView = UIImageView(image: NNImage.primaryLogo)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        imageView.preferredSymbolConfiguration = .init(pointSize: 80, weight: .regular)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private var flashTimer: Timer?
    private var isFlashingIn = false
    
    override func loadView() {
        super.loadView()
        
        startFlashingAnimation()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        view.addSubview(birdImageView)
        NSLayoutConstraint.activate([
            birdImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            birdImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            birdImageView.widthAnchor.constraint(equalToConstant: 120),
            birdImageView.heightAnchor.constraint(equalTo: birdImageView.widthAnchor)
        ])
    }
    
    private func startFlashingAnimation() {
        // Start with full opacity
        birdImageView.alpha = 1.0
        
        // Create and schedule the timer
        flashTimer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(animateBirdOpacity), userInfo: nil, repeats: true)
    }
    
    @objc private func animateBirdOpacity() {
        // Toggle between fading in and out
        isFlashingIn = !isFlashingIn
        
        // Target opacity based on direction
        let targetAlpha: CGFloat = isFlashingIn ? 1.0 : 0.3
        
        // Animate the opacity change
        UIView.animate(withDuration: 0.3) {
            self.birdImageView.alpha = targetAlpha
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Stop the timer when the view disappears
        flashTimer?.invalidate()
        flashTimer = nil
    }
} 
