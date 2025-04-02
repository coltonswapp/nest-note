import UIKit

class ToastTestViewController: NNViewController {
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    override func setup() {
        navigationItem.title = "Toast Test"
        
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Add test buttons
        let shortToastButton = createButton(title: "Show Short Toast", action: #selector(showShortToast))
        let longToastButton = createButton(title: "Show Long Toast", action: #selector(showLongToast))
        let multipleToastsButton = createButton(title: "Show Multiple Toasts", action: #selector(showMultipleToasts))
        let positiveToastButton = createButton(title: "Show Positive Toast", action: #selector(showPositiveToast))
        let negativeToastButton = createButton(title: "Show Negative Toast", action: #selector(showNegativeToast))
        let toastWithSubtitleButton = createButton(title: "Show Toast with Subtitle", action: #selector(showToastWithSubtitle))
        
        stackView.addArrangedSubview(shortToastButton)
        stackView.addArrangedSubview(longToastButton)
        stackView.addArrangedSubview(multipleToastsButton)
        stackView.addArrangedSubview(positiveToastButton)
        stackView.addArrangedSubview(negativeToastButton)
        stackView.addArrangedSubview(toastWithSubtitleButton)
    }
    
    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    @objc private func showShortToast() {
        showToast(text: "Short toast message")
    }
    
    @objc private func showLongToast() {
        showToast(text: "This is a very long toast message that should wrap to multiple lines and test the layout of the toast view")
    }
    
    @objc private func showMultipleToasts() {
        showToast(text: "First toast")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.showToast(text: "Second toast")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showToast(text: "Third toast")
        }
    }
    
    @objc private func showPositiveToast() {
        showToast(text: "Operation successful!", sentiment: .positive)
    }
    
    @objc private func showNegativeToast() {
        showToast(text: "Operation failed!", sentiment: .negative)
    }
    
    @objc private func showToastWithSubtitle() {
        showToast(text: "Profile Updated", subtitle: "Your changes have been saved", sentiment: .positive)
    }
} 