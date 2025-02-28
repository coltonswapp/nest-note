import UIKit

protocol SessionEventViewControllerDelegate: AnyObject {
    func sessionEventViewController(_ controller: SessionEventViewController, didCreateEvent event: SessionEvent?)
}

final class SessionEventViewController: NNSheetViewController {
    
    // MARK: - Properties
    weak var eventDelegate: SessionEventViewControllerDelegate?
    private let sessionID: String?
    private let event: SessionEvent?
    
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
        let button = NNSmallPrimaryButton(title: "Create Event", backgroundColor: .systemBlue)
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
    
    private let locationDividerView: UIView = {
        let view = UIView()
        view.backgroundColor = .quaternaryLabel
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var locationView: SessionEventLocationView = {
        let view = SessionEventLocationView(place: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.editButton.addTarget(self, action: #selector(showLocationSelector), for: .touchUpInside)
        view.delegate = self
        return view
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
    
    private let colorDividerView: UIView = {
        let view = UIView()
        view.backgroundColor = .quaternaryLabel
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var colorButtons: [UIButton] = []
    private var selectedColorIndex: Int = 0
    private var activeControl: ActiveDateControl?
    
    private enum ActiveDateControl {
        case startDate, startTime, endDate, endTime
    }
    
    // MARK: - Initialization
    init(sessionID: String? = nil, event: SessionEvent? = nil, sourceFrame: CGRect? = nil) {
        self.sessionID = sessionID
        self.event = event
        super.init(sourceFrame: sourceFrame)
        titleLabel.text = event == nil ? "New Event" : "Edit Event"
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
        
        // Configure with existing event if editing
        if let event = event {
            titleField.text = event.title
            startControl.date = event.startDate
            endControl.date = event.endDate
            
            // Set color selection
            if let colorIndex = colors.firstIndex(where: { $0 == event.eventColor }) {
                selectedColorIndex = colorIndex
            }
            
            Task {
                if let placeID = event.placeID {
                    await locationView.configureWith(PlacesService.shared.getPlace(for: placeID))
                }
            }
            
            // Update save button
            saveButton.setTitle("Update Event", for: .normal)
        }
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
        containerView.addSubview(locationDividerView)
        containerView.addSubview(endControl)
        containerView.addSubview(locationView)
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
            
            // Location divider constraints
            locationDividerView.topAnchor.constraint(equalTo: endControl.bottomAnchor, constant: 24),
            locationDividerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            locationDividerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            locationDividerView.heightAnchor.constraint(equalToConstant: 1),
            
            locationView.topAnchor.constraint(equalTo: locationDividerView.bottomAnchor, constant: 16),
            locationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            locationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            locationView.heightAnchor.constraint(equalToConstant: 60),
            
            // Color divider constraints
            colorDividerView.topAnchor.constraint(equalTo: locationView.bottomAnchor, constant: 24),
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
        guard let sessionID else { shakeContainerView(); return }
        
        guard let eventTitle = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !eventTitle.isEmpty else {
            shakeContainerView()
            return
        }
        
        guard validateDates() else {
            shakeContainerView()
            return
        }
        
        // Create or update the event
        let event = SessionEvent(
            id: self.event?.id ?? UUID().uuidString, // Keep existing ID if editing
            title: eventTitle,
            startDate: startControl.date,
            endDate: endControl.date,
            placeId: locationView.place?.id,
            eventColor: selectedColorType()
        )
        
        // Save using SessionService
        Task {
            do {
                // First, if we have a temporary place that hasn't been saved yet, save it
                if let place = locationView.place, place.isTemporary {
                    try await PlacesService.shared.saveTemporaryPlace(place)
                }
                
                // Then save the event
                try await SessionService.shared.updateSessionEvent(event, sessionID: sessionID)
                
                await MainActor.run {
                    eventDelegate?.sessionEventViewController(self, didCreateEvent: event)
                    dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to save event. Please try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
                Logger.log(level: .error, category: .sessionService, message: "Failed to save event: \(error.localizedDescription)")
            }
        }
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
    
    private func selectedColorType() -> NNColors.EventColors.ColorType {
        switch selectedColorIndex {
        case 0: return .blue
        case 1: return .lightBlue
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        case 6: return .black
        default: return .blue
        }
    }
    
    @objc func showLocationSelector() {
        let view = PlaceListViewController(isSelecting: true)
        view.selectionDelegate = self
        let nav = UINavigationController(rootViewController: view)
        present(nav, animated: true)
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
            endControl.date = date
            
        case .startTime:
            formatter.dateFormat = "h:mm a"
            startControl.timeText = formatter.string(from: date)
            startControl.date = date
            if startControl.date > endControl.date {
                endControl.date = startControl.date.addingTimeInterval(3600)
            }
            
        case .endDate:
            formatter.dateFormat = "MMM d, yyyy"
            endControl.dateText = formatter.string(from: date)
            endControl.date = date
            
        case .endTime:
            formatter.dateFormat = "h:mm a"
            endControl.timeText = formatter.string(from: date)
            endControl.date = date
            
            if endControl.date < startControl.date {
                startControl.date = endControl.date.addingTimeInterval(-3600)
            }
            
        case .none:
            break
        }
    }
}

extension SessionEventViewController: PlaceSelectionDelegate {
    func didSelectPlace(_ place: Place) {
        locationView.configureWith(place)
        locationView.thumbnailImageView.bounce()
    }
}

import MapKit

extension SessionEventViewController: PlaceAddressCellDelegate {
    func placeAddressCell(didTapThumbnail viewController: ImageViewerController) {
        present(viewController, animated: true)
    }
    
    func placeAddressCellAddressTapped(_ view: UIView, place: Place?) {
        guard let place else { return }
        if let view = view as? PlaceAddressCell {
            AddressActionHandler.presentAddressOptions(
                from: self,
                sourceView: view.addressLabel,
                address: place.address,
                coordinate: CLLocationCoordinate2D(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude),
                onCopy: {
                    view.showCopyFeedback()
                }
            )
        }
    }
}

class SessionEventLocationView: UIView {
    
    let emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .justified
        label.numberOfLines = 1
        label.text = "No location"
        return label
    }()
    
    let editButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.gray()
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .small
        button.configuration = configuration
        button.setTitle("Edit", for: .normal)
        return button
    }()
    
    let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    
    private let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }()
    
    private let aliasLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let addressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()
    
    weak var delegate: PlaceAddressCellDelegate?
    
    var place: Place?
    
    init(place: Place?) {
        super.init(frame: .zero)
        addSubviews()
        constrainSubviews()
        configureWith(place)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func addSubviews() {
        
        addSubview(emptyLabel)
        addSubview(editButton)
        
        labelStack.addArrangedSubview(aliasLabel)
        labelStack.addArrangedSubview(addressLabel)
        
        addSubview(thumbnailImageView)
        addSubview(labelStack)
    }
    
    func constrainSubviews() {
        NSLayoutConstraint.activate([
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            editButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            editButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            thumbnailImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            thumbnailImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 60),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 60),
            
            labelStack.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: editButton.leadingAnchor, constant: -16),
            labelStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func configureWith(_ place: Place?) {
        if let place {
            self.place = place
            
            let attributedString = NSAttributedString(
                string: place.address,
                attributes: [
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .font: UIFont.systemFont(ofSize: 16)
                ]
            )
            
            let addressTapGesture = UITapGestureRecognizer(target: self, action: #selector(addressTapped))
            addressLabel.isUserInteractionEnabled = true
            addressLabel.addGestureRecognizer(addressTapGesture)
            
            labelStack.isHidden = false
            
            // Handle temporary places differently
            if place.isTemporary {
                // For temporary places, show a placeholder icon instead of a thumbnail
                thumbnailImageView.image = UIImage(systemName: "mappin.circle.fill")
                thumbnailImageView.tintColor = .systemBlue
                thumbnailImageView.contentMode = .scaleAspectFit
                thumbnailImageView.isHidden = false
                
                // Remove image tap gesture for temporary places
                thumbnailImageView.gestureRecognizers?.forEach { thumbnailImageView.removeGestureRecognizer($0) }
            } else {
                // For permanent places, load the thumbnail and add tap gesture
                let imageTapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
                thumbnailImageView.addGestureRecognizer(imageTapGesture)
                thumbnailImageView.isHidden = false
                thumbnailImageView.contentMode = .scaleAspectFill
            
            
            aliasLabel.text = place.alias
            addressLabel.attributedText = attributedString
                
            aliasLabel.text = place.alias
            addressLabel.attributedText = attributedString
                Task {
                    do {
                        let image = try await PlacesService.shared.loadImages(for: place)
                        if aliasLabel.text == place.displayName {
                            thumbnailImageView.image = image
                        }
                    } catch {
                        thumbnailImageView.image = UIImage(systemName: "photo.fill")
                    }
                }
            }
            
            // Use displayName instead of alias to handle temporary places
            aliasLabel.text = place.displayName
            addressLabel.attributedText = attributedString
            emptyLabel.isHidden = true
        } else {
            emptyLabel.isHidden = false
            labelStack.isHidden = true
            thumbnailImageView.isHidden = true
        }
    }
    
    @objc private func addressTapped() {
        guard let viewController = findViewController() else { return }
        
        AddressActionHandler.presentAddressOptions(
            from: viewController,
            sourceView: addressLabel,
            address: addressLabel.text ?? "",
            onCopy: { [weak self] in
                self?.showCopyFeedback()
            }
        )
    }
    
    @objc private func imageTapped() {
        guard let image = thumbnailImageView.image else { return }
        let imageViewer = ImageViewerController(sourceImageView: thumbnailImageView)
        delegate?.placeAddressCell(didTapThumbnail: imageViewer)
    }
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
    
    func showCopyFeedback() {
        HapticsHelper.lightHaptic()
        
        let copiedLabel = UILabel()
        copiedLabel.text = "Copied!"
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        copiedLabel.textAlignment = .center
        copiedLabel.layer.cornerRadius = 10
        copiedLabel.clipsToBounds = true
        copiedLabel.alpha = 0
        
        addSubview(copiedLabel)
        copiedLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            copiedLabel.centerXAnchor.constraint(equalTo: addressLabel.centerXAnchor),
            copiedLabel.centerYAnchor.constraint(equalTo: addressLabel.centerYAnchor),
            copiedLabel.widthAnchor.constraint(equalToConstant: 100),
            copiedLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        UIView.animate(withDuration: 0.2) {
            copiedLabel.alpha = 1
        }
        
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
            copiedLabel.alpha = 0
        }) { _ in
            copiedLabel.removeFromSuperview()
        }
    }
    
}
