import UIKit

protocol SessionEventViewControllerDelegate: AnyObject {
    func sessionEventViewController(_ controller: SessionEventViewController, didCreateEvent event: SessionEvent?)
}

final class SessionEventViewController: NNSheetViewController {
    
    // MARK: - Properties
    weak var eventDelegate: SessionEventViewControllerDelegate?
    
    lazy var startControl: NNDateTimeControl = {
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
    
    lazy var endControl: NNDateTimeControl = {
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
    
    private let colorStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let colors: [NNColors.NNColorPair] = [
        NNColors.EventColors.blue,
        NNColors.EventColors.lightBlue,
        NNColors.EventColors.green,
        NNColors.EventColors.yellow,
        NNColors.EventColors.orange,
        NNColors.EventColors.red,
        NNColors.EventColors.black
    ]
    
    private var colorButtons: [UIButton] = []
    private var selectedColorIndex: Int = 0
    private var activeControl: ActiveDateControl?
    
    private enum ActiveDateControl {
        case startDate, startTime, endDate, endTime
    }
    
    struct SessionEvent {
        let title: String
        let startDate: Date
        let endDate: Date
        let color: UIColor
    }
    
    private let colorDividerView: UIView = {
        let view = UIView()
        view.backgroundColor = .quaternaryLabel
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Initialization
    override init(sourceFrame: CGRect? = nil) {
        super.init(sourceFrame: sourceFrame)
        titleLabel.text = "New Event"
        titleField.placeholder = "Event Title"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDateTimeControls()
        itemsHiddenDuringTransition = [buttonStackView]
    }
    
    // MARK: - Setup Methods
    override func addContentToContainer() {
        super.addContentToContainer()
        
        // Create labels
        let startLabel = UILabel()
        startLabel.text = "Starts"
        startLabel.font = .systemFont(ofSize: 16, weight: .medium)
        startLabel.textColor = .secondaryLabel
        startLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let endLabel = UILabel()
        endLabel.text = "Ends"
        endLabel.font = .systemFont(ofSize: 16, weight: .medium)
        endLabel.textColor = .secondaryLabel
        endLabel.translatesAutoresizingMaskIntoConstraints = false
        
        buttonStackView.addArrangedSubview(saveButton)
        
        // Add all views to container
        containerView.addSubview(startLabel)
        containerView.addSubview(startControl)
        containerView.addSubview(endLabel)
        containerView.addSubview(endControl)
        containerView.addSubview(colorDividerView)
        containerView.addSubview(colorStack)
        
        setupColorButtons()
        
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
            
            // Color divider constraints
            colorDividerView.topAnchor.constraint(equalTo: endControl.bottomAnchor, constant: 24),
            colorDividerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            colorDividerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            colorDividerView.heightAnchor.constraint(equalToConstant: 1),
            
            colorStack.topAnchor.constraint(equalTo: colorDividerView.bottomAnchor, constant: 36),
            colorStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            colorStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            colorStack.heightAnchor.constraint(equalToConstant: view.frame.width / 10),
            
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            buttonStackView.heightAnchor.constraint(equalToConstant: 46)
        ])
    }
    
    private func setupDateTimeControls() {
        let now = Date()
        startControl.date = now
        endControl.date = Calendar.current.date(byAdding: .minute, value: 45, to: now) ?? now
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
        
        if calendar.compare(startDate, to: endDate, toGranularity: .minute) == .orderedDescending {
            let alert = UIAlertController(
                title: "Invalid Time Range",
                message: "The start time cannot be after the end time.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return false
        }
        
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
        guard let eventTitle = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !eventTitle.isEmpty else {
            shakeContainerView()
            return
        }
        
        guard validateDates() else {
            shakeContainerView()
            return
        }
        
        let event = SessionEvent(
            title: eventTitle,
            startDate: startControl.date,
            endDate: endControl.date,
            color: colors[selectedColorIndex].border
        )
        
//        eventDelegate?.sessionEventViewController(self, didCreateEvent: event)
        dismiss(animated: true)
    }
    
    private func presentPickerSheet(for mode: UIDatePicker.Mode, type: NNDateTimePickerSheet.PickerType) {
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
    
    private func setupColorButtons() {
        let cornerRadius: CGFloat = 20
        let size: CGFloat = view.frame.width / 10
        print("size: \(size)")
        
        for (index, color) in colors.enumerated() {
            let button = UIButton()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tag = index
            button.layer.cornerRadius = cornerRadius
            button.clipsToBounds = true
            button.backgroundColor = color.fill
            button.layer.borderColor = color.border.cgColor
            button.layer.borderWidth = index == selectedColorIndex ? 6 : 3
            button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
            
            colorButtons.append(button)
            colorStack.addArrangedSubview(button)
            
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: size),
                button.widthAnchor.constraint(equalToConstant: size),
            ])
        }
    }
    
    @objc private func colorButtonTapped(_ sender: UIButton) {
        HapticsHelper.lightHaptic()
        // Update border for previously selected button
        UIView.animate(withDuration: 0.1) { [weak self] in
            guard let self else { return }
            colorButtons[selectedColorIndex].layer.borderWidth = 3
            colorButtons[selectedColorIndex].transform = .identity
            
            // Update selected index and new button border
            selectedColorIndex = sender.tag
            sender.transform = .init(scaleX: 1.4, y: 1.4)
            sender.layer.borderWidth = 6
            sender.bounce()
        }
    }
}

// MARK: - NNDateTimePickerSheetDelegate
extension SessionEventViewController: NNDateTimePickerSheetDelegate {
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
