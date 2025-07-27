import UIKit

protocol SessionDetailViewControllerDelegate: AnyObject {
//    func sessionDetailViewController(_ controller: SessionDetailViewController, didCreateSession session: Session?)
}

final class SessionDetailViewController: NNSheetViewController {
    
    // MARK: - Properties
    weak var sessionDelegate: SessionDetailViewControllerDelegate?
    
    private var session: (any SessionDisplayable)?
    private var isArchived: Bool = false
    
    private lazy var startControl: NNDateTimeControl = {
        let control = NNDateTimeControl(style: .both, type: .start)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.onDateTapped = { [weak self] in
            self?.startDateTapped()
        }
        control.onTimeTapped = { [weak self] in
            self?.startTimeTapped()
        }
        return control
    }()
    
    private lazy var endControl: NNDateTimeControl = {
        let control = NNDateTimeControl(style: .time, type: .end)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.onDateTapped = { [weak self] in
            self?.endDateTapped()
        }
        control.onTimeTapped = { [weak self] in
            self?.endTimeTapped()
        }
        return control
    }()
    
    lazy private var multiDayToggle: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.addTarget(self, action: #selector(multiDayToggleTapped), for: .valueChanged)
        toggle.isOn = false 
        return toggle
    }()
    
    private let multiDayLabel: UILabel = {
        let label = UILabel()
        label.text = "Multi-day session"
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var saveButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(title: "Next", backgroundColor: .systemBlue)
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // Add a property to track the active control
    private enum ActiveDateControl {
        case startDate, startTime, endDate, endTime
    }
    private var activeControl: ActiveDateControl?
    
    // MARK: - Initialization
    override init(sourceFrame: CGRect? = nil) {
        super.init(sourceFrame: sourceFrame)
        titleLabel.text = "New Session"
        titleField.placeholder = "i.e. Anniversary in Cabo"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    func configure(with session: any SessionDisplayable) {
        self.session = session
        self.isArchived = session.status == .archived
        
        // Update UI based on session data
        titleLabel.text = isArchived ? "Archived Session" : "Session Details"
        titleField.text = session.title
        titleField.isEnabled = !isArchived
        
        // Set date controls
        startControl.date = session.startDate
        endControl.date = session.endDate
        
        // Format dates for display
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        startControl.dateText = dateFormatter.string(from: session.startDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        startControl.timeText = timeFormatter.string(from: session.startDate)
        endControl.timeText = timeFormatter.string(from: session.endDate)
        
        // Set multi-day toggle
        if let sessionItem = session as? SessionItem {
            multiDayToggle.isOn = sessionItem.isMultiDay
        } else {
            // For archived sessions, we don't have isMultiDay, so we'll infer it
            let calendar = Calendar.current
            let startDay = calendar.startOfDay(for: session.startDate)
            let endDay = calendar.startOfDay(for: session.endDate)
            multiDayToggle.isOn = startDay != endDay
        }
        
        // Update end control style based on multi-day
        endControl.setStyle(multiDayToggle.isOn ? .both : .time, animated: false)
        
        // Disable controls for archived sessions
        startControl.isUserInteractionEnabled = !isArchived
        endControl.isUserInteractionEnabled = !isArchived
        multiDayToggle.isEnabled = !isArchived
        
        // Hide save button for archived sessions
        saveButton.isHidden = isArchived
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDateTimeControls()
        itemsHiddenDuringTransition = [buttonStackView]
    }
    
    // MARK: - Setup Methods
    
    override func setupInfoButton() {
        // SessionDetailViewController doesn't need an info button
        infoButton.isHidden = true
    }
    
    override func addContentToContainer() {
        super.addContentToContainer()
        
        // Create labels
        let startLabel = UILabel()
        startLabel.text = "Starts"
        startLabel.font = .bodyL
        startLabel.textColor = .secondaryLabel
        startLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let endLabel = UILabel()
        endLabel.text = "Ends"
        endLabel.font = .bodyL
        endLabel.textColor = .secondaryLabel
        endLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create multi-day row
        let multiDayStack = UIStackView(arrangedSubviews: [multiDayLabel, multiDayToggle])
        multiDayStack.axis = .horizontal
        multiDayStack.spacing = 8
        multiDayStack.alignment = .center
        multiDayStack.translatesAutoresizingMaskIntoConstraints = false
        
        buttonStackView.addArrangedSubview(saveButton)
        
        // Add all views to container
        containerView.addSubview(startLabel)
        containerView.addSubview(startControl)
        
        containerView.addSubview(endLabel)
        containerView.addSubview(endControl)
        
        containerView.addSubview(multiDayStack)
        containerView.addSubview(buttonStackView)
        
        NSLayoutConstraint.activate([
            // Start label constraints
            startLabel.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 24),
            startLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            // Start control constraints
            startControl.centerYAnchor.constraint(equalTo: startLabel.centerYAnchor),
            startControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            startControl.leadingAnchor.constraint(greaterThanOrEqualTo: startLabel.trailingAnchor, constant: 16),
            
            // End label constraints
            endLabel.topAnchor.constraint(equalTo: startLabel.bottomAnchor, constant: 24),
            endLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            endLabel.widthAnchor.constraint(equalTo: startLabel.widthAnchor),
            
            // End control constraints
            endControl.centerYAnchor.constraint(equalTo: endLabel.centerYAnchor),
            endControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            endControl.leadingAnchor.constraint(greaterThanOrEqualTo: endLabel.trailingAnchor, constant: 16),
            
            // Multi-day stack constraints
            multiDayStack.topAnchor.constraint(equalTo: endLabel.bottomAnchor, constant: 24),
            multiDayStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            multiDayStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Button stack constraints
            buttonStackView.topAnchor.constraint(greaterThanOrEqualTo: multiDayStack.bottomAnchor, constant: 24),
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            buttonStackView.heightAnchor.constraint(equalToConstant: 46)
        ])
    }
    
    private func setupDateTimeControls() {
        startControl.onDateTapped = { [weak self] in
            self?.startDateTapped()
        }
        startControl.onTimeTapped = { [weak self] in
            self?.startTimeTapped()
        }
        
        endControl.onDateTapped = { [weak self] in
            self?.endDateTapped()
        }
        endControl.onTimeTapped = { [weak self] in
            self?.endTimeTapped()
        }
    }
    
    @objc func multiDayToggleTapped() {
        endControl.setStyle(multiDayToggle.isOn ? .both : .time, animated: true)
        
        // If turning off multi-day, sync the end date with start date
        if !multiDayToggle.isOn {
            let calendar = Calendar.current
            
            // Get date components from start date
            let startComponents = calendar.dateComponents([.year, .month, .day], from: startControl.date)
            // Get time components from end date (to preserve the end time)
            let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endControl.date)
            
            // Combine the start date with end time
            var newComponents = DateComponents()
            newComponents.year = startComponents.year
            newComponents.month = startComponents.month
            newComponents.day = startComponents.day
            newComponents.hour = endTimeComponents.hour
            newComponents.minute = endTimeComponents.minute
            
            // Create new date and update end control
            if let newDate = calendar.date(from: newComponents) {
                endControl.date = newDate
            }
        }
    }
    
    // MARK: - Actions
    @objc private func startDateTapped() {
        activeControl = .startDate
        presentPickerSheet(for: .date, type: .startDate)
    }
    
    @objc private func startTimeTapped() {
        activeControl = .startTime
        presentPickerSheet(for: .time, type: .startTime)
    }
    
    @objc private func endDateTapped() {
        activeControl = .endDate
        presentPickerSheet(for: .date, type: .endDate)
    }
    
    @objc private func endTimeTapped() {
        activeControl = .endTime
        presentPickerSheet(for: .time, type: .endTime)
    }
    
    private func validateDates() -> Bool {
        let calendar = Calendar.current
        let startDate = startControl.date
        let endDate = endControl.date
        
        // Compare dates
        if calendar.compare(startDate, to: endDate, toGranularity: .minute) == .orderedDescending {
            // Start date is after end date - show error
            let alert = UIAlertController(
                title: "Invalid Time Range",
                message: "The start time cannot be after the end time.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return false
        }
        
        // Optionally, we could also check if they're exactly equal
        if calendar.compare(startDate, to: endDate, toGranularity: .minute) == .orderedSame {
            let alert = UIAlertController(
                title: "Invalid Time Range",
                message: "The start and end times cannot be the same.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return false
        }
        
        return true
    }
    
    @objc private func saveButtonTapped() {
        print("Start date: \(startControl.date)")
        print("End date: \(endControl.date)")
        
        guard let sessionName = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sessionName.isEmpty else {
            shakeContainerView()
            return
        }
        
        // Validate dates before proceeding
        guard validateDates() else {
            shakeContainerView()
            return
        }
        
        // If we get here, dates are valid
        dismiss(animated: true)
    }
    
    private func presentPickerSheet(for mode: UIDatePicker.Mode, type: NNDateTimePickerSheet.PickerType) {
        // Get the current date from the appropriate control
        let currentDate: Date
        switch type {
        case .startDate, .startTime:
            currentDate = startControl.date
        case .endDate, .endTime:
            currentDate = endControl.date
        }
        
        let pickerVC = NNDateTimePickerSheet(mode: mode, type: type, initialDate: currentDate)
        pickerVC.delegate = self
        
        let nav = UINavigationController(rootViewController: pickerVC)
        
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.custom(resolver: { context in
                return 300
            })]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        
        present(nav, animated: true)
    }
}

extension SessionDetailViewController: NNDateTimePickerSheetDelegate {
    func dateTimePickerSheet(_ sheet: NNDateTimePickerSheet, didSelectDate date: Date) {
        let formatter = DateFormatter()
        
        switch activeControl {
        case .startDate:
            formatter.dateFormat = "MMM d, yyyy"
            startControl.dateText = formatter.string(from: date)
            startControl.date = date
            
        case .startTime:
            formatter.dateFormat = "h:mm a"
            startControl.timeText = formatter.string(from: date)
            startControl.date = date
            
        case .endDate:
            formatter.dateFormat = "MMM d, yyyy"
            endControl.dateText = formatter.string(from: date)
            endControl.date = date
            
        case .endTime:
            formatter.dateFormat = "h:mm a"
            endControl.timeText = formatter.string(from: date)
            endControl.date = date
            
        case .none:
            break
        }
    }
} 
