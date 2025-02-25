import UIKit

class GlassyButtonPlayground: UIViewController {
    
    // MARK: - Properties
    private let button = GlassyButton(frame: .zero)
    
    private lazy var mainBorderSlider = createSlider(
        value: 5.0,
        minimum: 0.0,
        maximum: 15.0,
        action: #selector(mainBorderWidthChanged)
    )
    
    private lazy var thinBorderSlider = createSlider(
        value: 1.5,
        minimum: 0.0,
        maximum: 5.0,
        action: #selector(thinBorderWidthChanged)
    )
    
    private lazy var innerBorderSlider = createSlider(
        value: 1.5,
        minimum: 0.0,
        maximum: 5.0,
        action: #selector(innerBorderWidthChanged)
    )
    
    private lazy var backgroundColorPicker: UIColorPickerViewController = {
        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.selectedColor = NNColors.primary
        return picker
    }()
    
    private lazy var titleColorPicker: UIColorPickerViewController = {
        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.selectedColor = .white
        return picker
    }()
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Glassy Button Playground"
        
        // Configure button
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Glassy Button", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.backgroundColor = NNColors.primary
        
        // Add subviews
        view.addSubview(stackView)
        
        // Create labels and controls
        let controls: [(String, UIView)] = [
            ("Button", button),
            ("Main Border Width", createControlRow(slider: mainBorderSlider, value: 5.0)),
            ("Thin Border Width", createControlRow(slider: thinBorderSlider, value: 1.5)),
            ("Inner Border Width", createControlRow(slider: innerBorderSlider, value: 1.5)),
            ("Background Color", createColorButton(title: "Select Background Color", action: #selector(showBackgroundColorPicker))),
            ("Title Color", createColorButton(title: "Select Title Color", action: #selector(showTitleColorPicker)))
        ]
        
        controls.forEach { title, control in
            let rowStack = UIStackView()
            rowStack.axis = .vertical
            rowStack.spacing = 8
            
            let label = UILabel()
            label.text = title
            label.font = .systemFont(ofSize: 14, weight: .medium)
            
            rowStack.addArrangedSubview(label)
            rowStack.addArrangedSubview(control)
            
            stackView.addArrangedSubview(rowStack)
        }
        
        // Constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            button.heightAnchor.constraint(equalToConstant: 55)
        ])
        button.layer.cornerRadius = 55 / 2
    }
    
    private func createSlider(value: Float, minimum: Float, maximum: Float, action: Selector) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = minimum
        slider.maximumValue = maximum
        slider.value = value
        slider.addTarget(self, action: action, for: .valueChanged)
        return slider
    }
    
    private func createControlRow(slider: UISlider, value: Float) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        
        let valueLabel = UILabel()
        valueLabel.text = String(format: "%.1f", value)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        slider.addAction(UIAction { _ in
            valueLabel.text = String(format: "%.1f", slider.value)
        }, for: .valueChanged)
        
        stack.addArrangedSubview(slider)
        stack.addArrangedSubview(valueLabel)
        
        return stack
    }
    
    private func createColorButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    // MARK: - Actions
    @objc private func mainBorderWidthChanged(_ slider: UISlider) {
        button.updateBorderWidths(main: CGFloat(slider.value))
    }
    
    @objc private func thinBorderWidthChanged(_ slider: UISlider) {
        button.updateBorderWidths(thin: CGFloat(slider.value))
    }
    
    @objc private func innerBorderWidthChanged(_ slider: UISlider) {
        button.updateBorderWidths(inner: CGFloat(slider.value))
    }
    
    @objc private func showBackgroundColorPicker() {
        present(backgroundColorPicker, animated: true)
    }
    
    @objc private func showTitleColorPicker() {
        present(titleColorPicker, animated: true)
    }
}

// MARK: - UIColorPickerViewControllerDelegate
extension GlassyButtonPlayground: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        if viewController === backgroundColorPicker {
            button.backgroundColor = viewController.selectedColor
        } else if viewController === titleColorPicker {
            button.setTitleColor(viewController.selectedColor, for: .normal)
        }
    }
    
    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        if viewController === backgroundColorPicker {
            button.backgroundColor = color
        } else if viewController === titleColorPicker {
            button.setTitleColor(color, for: .normal)
        }
    }
} 
