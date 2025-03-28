import UIKit

class ImageViewerController: UIViewController {
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let dismissButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "xmark.circle.fill", withConfiguration: config)?
            .withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private var panGestureStartPoint: CGPoint?
    private var initialImageViewCenter: CGPoint?
    
    init(sourceImageView: UIImageView) {
        super.init(nibName: nil, bundle: nil)
        imageView.image = sourceImageView.image
        modalPresentationStyle = .custom
        transitioningDelegate = ImageViewerTransitioningDelegate(sourceImageView: sourceImageView)
        
        // Haptic feedback when presenting
        HapticsHelper.lightHaptic()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupPanGesture()
    }
    
    private func setup() {
        view.backgroundColor = .black
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        view.addSubview(dismissButton)
        
        scrollView.delegate = self
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            scrollView.frameLayoutGuide.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.frameLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.frameLayoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.frameLayoutGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            
            dismissButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            dismissButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            dismissButton.widthAnchor.constraint(equalToConstant: 44),
            dismissButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Add double-tap to zoom gesture
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)
    }
    
    private func setupPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)
    }
    
    @objc private func dismissTapped() {
        // Use animated: false to prevent delay
        dismiss(animated: false)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let size = CGSize(
                width: scrollView.bounds.width / scrollView.maximumZoomScale,
                height: scrollView.bounds.height / scrollView.maximumZoomScale
            )
            let origin = CGPoint(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2
            )
            scrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .began:
            panGestureStartPoint = gesture.location(in: view)
            initialImageViewCenter = imageView.center
            
        case .changed:
            guard let startPoint = panGestureStartPoint else { return }
            
            let verticalDelta = translation.y
            let progress = min(1.0, abs(verticalDelta) / 200)
            
            // Calculate scale based on vertical movement (0.5 to 1.0)
            let scale = max(0.5, min(1.0, 1.0 - abs(verticalDelta) / 1000))
            
            // Calculate rotation based on horizontal movement (-10° to 10°)
            let rotation = min(10, max(-10, translation.x / 20))
            let angleInRadians = rotation * .pi / 180
            
            // Apply transformations
            let transform = CGAffineTransform.identity
                .translatedBy(x: translation.x, y: verticalDelta)
                .scaledBy(x: scale, y: scale)
                .rotated(by: angleInRadians)
            
            imageView.transform = transform
            
            // Fade out background and dismiss button
            view.backgroundColor = UIColor.black.withAlphaComponent(1 - progress)
            dismissButton.alpha = 1 - progress
            
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view)
            let translation = gesture.translation(in: view)
            
            let shouldDismiss = abs(velocity.y) > 500 || abs(translation.y) > 200
            
            if shouldDismiss {
                // Play haptic before starting dismiss animation
                HapticsHelper.lightHaptic()
                
                // Calculate final position - center X, below screen
                let screenHeight = UIScreen.main.bounds.height
                let margin: CGFloat = 100
                
                let finalTranslation = CGPoint(
                    x: 0, // Keep X centered
                    y: screenHeight + margin // Move below screen
                )
                
                let velocity = sqrt(pow(gesture.velocity(in: view).x, 2) + pow(gesture.velocity(in: view).y, 2))
                let duration = min(0.5, max(0.3, 1500 / velocity))
                
                UIView.animate(withDuration: duration,
                              delay: 0,
                              options: [.curveEaseOut]) {
                    let transform = CGAffineTransform.identity
                        .translatedBy(x: finalTranslation.x, y: finalTranslation.y)
                        .scaledBy(x: 0.3, y: 0.3)
                    
                    self.imageView.transform = transform
                    self.view.backgroundColor = .clear
                    self.dismissButton.alpha = 0
                } completion: { _ in
                    self.dismiss(animated: false)
                }
            } else {
                // Spring back animation...
                UIView.animate(withDuration: 0.5,
                             delay: 0,
                             usingSpringWithDamping: 0.8,
                             initialSpringVelocity: 0.2,
                             options: .curveEaseOut) {
                    self.imageView.transform = .identity
                    self.view.backgroundColor = .black
                    self.dismissButton.alpha = 1
                }
            }
            
        default:
            break
        }
    }
}

extension ImageViewerController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
} 
