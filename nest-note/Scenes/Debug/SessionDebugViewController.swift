import UIKit

class SessionDebugViewController: NNViewController {
    
    // MARK: - Properties
    
    private let controlStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let showButton: UIButton = {
        let button = UIButton(configuration: .filled())
        button.setTitle("Show Session Bar", for: .normal)
        return button
    }()
    
    private let hideButton: UIButton = {
        let button = UIButton(configuration: .filled())
        button.setTitle("Hide Session Bar", for: .normal)
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Session Bar Debug"
        setupButtons()
    }
    
    // MARK: - Setup
    
    override func addSubviews() {
        view.addSubview(controlStack)
        controlStack.addArrangedSubview(showButton)
        controlStack.addArrangedSubview(hideButton)
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            controlStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            controlStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            controlStack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7)
        ])
    }
    
    private func setupButtons() {
        showButton.addTarget(self, action: #selector(showButtonTapped), for: .touchUpInside)
        hideButton.addTarget(self, action: #selector(hideButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func showButtonTapped() {
        SessionManager.shared.showSessionBar()
    }
    
    @objc private func hideButtonTapped() {
        SessionManager.shared.hideSessionBar()
    }
} 
