import UIKit

protocol NNDateTimePickerSheetDelegate: AnyObject {
    func dateTimePickerSheet(_ sheet: NNDateTimePickerSheet, didSelectDate date: Date)
}

final class NNDateTimePickerSheet: UIViewController {
    
    // MARK: - Properties
    weak var delegate: NNDateTimePickerSheetDelegate?
    
    private let picker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()
    
    private let confirmButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Confirm", image: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let mode: UIDatePicker.Mode
    private let initialDate: Date
    let pickerType: PickerType
    let pickerInterval: Int
    
    // Add an enum to specify the type of picker
    enum PickerType {
        case startDate
        case endDate
        case startTime
        case endTime
        
        var title: String {
            switch self {
            case .startDate: return "Select Start Date"
            case .endDate: return "Select End Date"
            case .startTime: return "Select Start Time"
            case .endTime: return "Select End Time"
            }
        }
    }
    
    // MARK: - Initialization
    init(mode: UIDatePicker.Mode, type: PickerType, initialDate: Date = Date(), interval: Int = 10) {
        self.mode = mode
        self.pickerType = type
        self.initialDate = initialDate
        self.pickerInterval = interval
        super.init(nibName: nil, bundle: nil)
        self.title = pickerType.title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupActions()
    }
    
    // MARK: - Setup
    private func setupView() {
        view.backgroundColor = .systemBackground
        
        picker.datePickerMode = mode
        picker.minuteInterval = pickerInterval
        picker.preferredDatePickerStyle = .wheels
        picker.date = initialDate
        view.addSubview(picker)
        view.addSubview(confirmButton)
        
        NSLayoutConstraint.activate([
            
            picker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -16),
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            confirmButton.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 4),
            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            confirmButton.heightAnchor.constraint(equalToConstant: 46)
        ])
    }
    
    private func setupActions() {
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func confirmButtonTapped() {
        delegate?.dateTimePickerSheet(self, didSelectDate: picker.date)
        dismiss(animated: true)
    }
} 
