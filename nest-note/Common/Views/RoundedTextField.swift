import UIKit

/// A custom UIView that wraps a UITextField with rounded corners and padding
class RoundedTextField: UIView {
    
    // MARK: - Properties
    
    /// The embedded text field
    public let textField = UITextField()
    
    /// Convenience property to access the text field's text
    public var text: String? {
        get { return textField.text }
        set { textField.text = newValue }
    }
    
    /// Convenience property to access the text field's placeholder
    public var placeholder: String? {
        get { return textField.placeholder }
        set { textField.placeholder = newValue }
    }
    
    /// Convenience property to access the text field's delegate
    public weak var delegate: UITextFieldDelegate? {
        get { return textField.delegate }
        set { textField.delegate = newValue }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    convenience init(placeholder: String? = nil) {
        self.init(frame: .zero)
        self.placeholder = placeholder
    }
    
    // MARK: - Setup
    
    private func setupView() {
        // Configure the container view
        backgroundColor = .tertiarySystemGroupedBackground
        layer.cornerRadius = 18
        clipsToBounds = true
        
        // Configure the text field
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)
        
        // Set up constraints with 8pt padding on leading and trailing edges
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }
    
    // MARK: - UITextField Forwarding
    
    /// Configures the text field with common input types
    public func configureFor(inputType: TextFieldInputType) {
        switch inputType {
        case .email:
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            
        case .password:
            textField.isSecureTextEntry = true
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            
        case .phone:
            textField.keyboardType = .phonePad
            
        case .number:
            textField.keyboardType = .numberPad
            
        case .default:
            textField.keyboardType = .default
        }
    }
    
    /// Convenience method to make the text field the first responder
    @discardableResult
    override public func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }
    
    /// Convenience method to resign first responder status
    @discardableResult
    override public func resignFirstResponder() -> Bool {
        return textField.resignFirstResponder()
    }
}

/// Enum defining common text field input types
public enum TextFieldInputType {
    case email
    case password
    case phone
    case number
    case `default`
} 
