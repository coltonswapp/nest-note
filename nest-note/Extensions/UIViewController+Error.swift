import UIKit

extension UIViewController {
    func showError(_ message: String, duration: TimeInterval = 3.0) {
        let errorView = UIView()
        errorView.backgroundColor = .systemRed
        errorView.alpha = 0
        errorView.layer.cornerRadius = 8
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .medium)
        
        errorView.addSubview(label)
        view.addSubview(errorView)
        
        // Configure constraints
        errorView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            label.topAnchor.constraint(equalTo: errorView.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: errorView.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -12)
        ])
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            errorView.alpha = 1
        }
        
        // Animate out after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            UIView.animate(withDuration: 0.3) {
                errorView.alpha = 0
            } completion: { _ in
                errorView.removeFromSuperview()
            }
        }
    }
} 