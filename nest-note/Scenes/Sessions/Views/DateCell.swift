//
//  DateCell.swift
//  nest-note
//
//  Created by Colton Swapp on 12/31/24.
//

import UIKit

final class DateCell: UICollectionViewListCell {
    private var startControl: NNDateTimeControl!
    private var endControl: NNDateTimeControl!
    private var earlyAccessButton: UIButton!
    private var multiDayToggle: UISwitch!
    
    weak var delegate: DatePresentationDelegate?
    private var startDate: Date = Date()
    private var endDate: Date = Date()
    private var isMultiDay: Bool = false
    private var earlyAccessDuration: EarlyAccessDuration = .halfDay
    
    private var isReadOnly: Bool = false
    
    // Create labels
    let startLabel: UILabel = {
        let label = UILabel()
        label.text = "Starts"
        label.font = .bodyL
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let endLabel: UILabel = {
        let label = UILabel()
        label.text = "Ends"
        label.font = .bodyL
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    let earlyAccessLabel: UILabel = {
        let label = UILabel()
        label.text = "Early Access"
        label.font = .bodyL
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let multiDayLabel: UILabel = {
        let label = UILabel()
        label.text = "Multi-day session"
        label.font = .bodyL
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupControls()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupControls() {
        startControl = NNDateTimeControl(style: .both, type: .start)
        endControl = NNDateTimeControl(style: .time, type: .end)
        
        // Setup early access button to match DateTimeButton style
        earlyAccessButton = UIButton(type: .system)
        earlyAccessButton.setTitle("12 hours", for: .normal)
        earlyAccessButton.titleLabel?.font = .bodyL
        earlyAccessButton.setTitleColor(.label, for: .normal)
        earlyAccessButton.backgroundColor = NNColors.NNSystemBackground4
        earlyAccessButton.layer.cornerRadius = 8
        earlyAccessButton.showsMenuAsPrimaryAction = true
        earlyAccessButton.menu = createEarlyAccessMenu()
        
        // Add chevron image with size constraint to match font height (16pt)
        let chevronConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let chevronImage = UIImage(systemName: "chevron.up.chevron.down", withConfiguration: chevronConfiguration)
        earlyAccessButton.setImage(chevronImage, for: .normal)
        earlyAccessButton.tintColor = .secondaryLabel
        earlyAccessButton.semanticContentAttribute = .forceRightToLeft
        earlyAccessButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        
        // Set content insets to match DateTimeButton padding, with extra right padding for chevron
        earlyAccessButton.contentEdgeInsets = UIEdgeInsets(top: 6.0, left: 10.0, bottom: 6.0, right: 16.0)
        
        // Add highlight animation behavior
        earlyAccessButton.addTarget(self, action: #selector(earlyAccessButtonTouchDown), for: .touchDown)
        earlyAccessButton.addTarget(self, action: #selector(earlyAccessButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        multiDayToggle = UISwitch()
        
        startControl.translatesAutoresizingMaskIntoConstraints = false
        endControl.translatesAutoresizingMaskIntoConstraints = false
        earlyAccessButton.translatesAutoresizingMaskIntoConstraints = false
        multiDayToggle.translatesAutoresizingMaskIntoConstraints = false

        // Setup callbacks
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
        multiDayToggle.addTarget(self, action: #selector(multiDayToggleTapped), for: .valueChanged)
        
        // Add to content view
        contentView.addSubview(startLabel)
        contentView.addSubview(startControl)
        contentView.addSubview(endLabel)
        contentView.addSubview(endControl)
        contentView.addSubview(earlyAccessLabel)
        contentView.addSubview(earlyAccessButton)
        contentView.addSubview(multiDayLabel)
        contentView.addSubview(multiDayToggle)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Start label constraints
            startLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            startLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            // Start control constraints
            startControl.centerYAnchor.constraint(equalTo: startLabel.centerYAnchor),
            startControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            startControl.leadingAnchor.constraint(greaterThanOrEqualTo: startLabel.trailingAnchor, constant: 16),
            
            // End label constraints
            endLabel.topAnchor.constraint(equalTo: startLabel.bottomAnchor, constant: 24),
            endLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            endLabel.widthAnchor.constraint(equalTo: startLabel.widthAnchor),
            
            // End control constraints
            endControl.centerYAnchor.constraint(equalTo: endLabel.centerYAnchor),
            endControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            endControl.leadingAnchor.constraint(greaterThanOrEqualTo: endLabel.trailingAnchor, constant: 16),
            
            multiDayLabel.topAnchor.constraint(equalTo: endLabel.bottomAnchor, constant: 24),
            multiDayLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            // Multi-day toggle constraints
            multiDayToggle.centerYAnchor.constraint(equalTo: multiDayLabel.centerYAnchor),
            multiDayToggle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Early access label constraints
            earlyAccessLabel.topAnchor.constraint(equalTo: multiDayLabel.bottomAnchor, constant: 24),
            earlyAccessLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            earlyAccessLabel.widthAnchor.constraint(equalTo: startLabel.widthAnchor),
            earlyAccessLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            // Early access button constraints
            earlyAccessButton.centerYAnchor.constraint(equalTo: earlyAccessLabel.centerYAnchor),
            earlyAccessButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            earlyAccessButton.leadingAnchor.constraint(greaterThanOrEqualTo: earlyAccessLabel.trailingAnchor, constant: 16)
        ])
    }
    
    func configure(startDate: Date, endDate: Date, isMultiDay: Bool, isReadOnly: Bool = false) {
        self.startDate = startDate
        self.endDate = endDate
        self.isMultiDay = isMultiDay
        self.isReadOnly = isReadOnly
        
        startControl.date = startDate
        endControl.date = endDate
        multiDayToggle.isOn = isMultiDay
        endControl.setStyle(isMultiDay ? .both : .time, animated: false)
        
        startControl.isEnabled = !isReadOnly
        endControl.isEnabled = !isReadOnly
        earlyAccessButton.isEnabled = !isReadOnly
        multiDayToggle.isEnabled = !isReadOnly
        
        // Update early access button appearance for disabled state
        updateEarlyAccessButtonEnabledState()
        
        updateDateLabels()
        updateEarlyAccessButton()
    }
    
    func configure(startDate: Date, endDate: Date, isMultiDay: Bool, earlyAccessDuration: EarlyAccessDuration, isReadOnly: Bool = false) {
        self.earlyAccessDuration = earlyAccessDuration
        configure(startDate: startDate, endDate: endDate, isMultiDay: isMultiDay, isReadOnly: isReadOnly)
    }
    
    private func updateDateLabels() {
        let formatter = DateFormatter()
        
        // Update start control
        formatter.dateFormat = "MMM d, yyyy"
        startControl.dateText = formatter.string(from: startDate)
        formatter.dateFormat = "h:mm a"
        startControl.timeText = formatter.string(from: startDate)
        
        // Update end control
        if isMultiDay {
            formatter.dateFormat = "MMM d, yyyy"
            endControl.dateText = formatter.string(from: endDate)
        }
        formatter.dateFormat = "h:mm a"
        endControl.timeText = formatter.string(from: endDate)
        
        endControl.setStyle(isMultiDay ? .both : .time, animated: true)
    }
    
    private func startDateTapped() {
        delegate?.presentDatePicker(for: .startDate, initialDate: startDate)
    }
    
    private func startTimeTapped() {
        delegate?.presentDatePicker(for: .startTime, initialDate: startDate)
    }
    
    private func endDateTapped() {
        delegate?.presentDatePicker(for: .endDate, initialDate: endDate)
    }
    
    private func endTimeTapped() {
        delegate?.presentDatePicker(for: .endTime, initialDate: endDate)
    }
    
    @objc private func multiDayToggleTapped() {
        let newMultiDayState = multiDayToggle.isOn
        
        if !newMultiDayState {
            // Toggling OFF multi-day - allow immediately
            isMultiDay = false
            endControl.setStyle(.time, animated: true)
            
            // Sync end date with start date
            let calendar = Calendar.current
            let startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
            let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endDate)
            
            var newComponents = DateComponents()
            newComponents.year = startComponents.year
            newComponents.month = startComponents.month
            newComponents.day = startComponents.day
            newComponents.hour = endTimeComponents.hour
            newComponents.minute = endTimeComponents.minute
            
            if let newDate = calendar.date(from: newComponents) {
                updateDates(newEndDate: newDate)
            }
        } else {
            // Toggling ON multi-day - let delegate validate first
            // Don't update isMultiDay yet - let the delegate decide
            delegate?.didToggleMultiDay(newMultiDayState, startDate: startDate, endDate: endDate)
        }
    }
    
    private func updateDates(newStartDate: Date? = nil, newEndDate: Date? = nil) {
        if let newStartDate = newStartDate {
            startDate = newStartDate
        }
        if let newEndDate = newEndDate {
            endDate = newEndDate
        }
        
        // Update the UI
        updateDateLabels()
        
        // Notify delegate of the change
        delegate?.didToggleMultiDay(isMultiDay, startDate: startDate, endDate: endDate)
    }
    
    // Method to revert the multi-day toggle when subscription check fails
    func revertMultiDayToggle() {
        // Revert the switch to previous state
        multiDayToggle.isOn = false
        isMultiDay = false
        
        // Revert the UI state
        endControl.setStyle(.time, animated: true)
        updateDateLabels()
    }
    
    // Method to enable multi-day when subscription check passes
    func enableMultiDay() {
        isMultiDay = true
        endControl.setStyle(.both, animated: true)
        updateDateLabels()
    }
    
    private func createEarlyAccessMenu() -> UIMenu {
        let actions = EarlyAccessDuration.allCases.map { duration in
            UIAction(title: duration.displayName, state: duration == earlyAccessDuration ? .on : .off) { [weak self] _ in
                self?.earlyAccessDuration = duration
                self?.updateEarlyAccessButton()
                self?.delegate?.didChangeEarlyAccess(duration)
            }
        }
        
        return UIMenu(title: "Select Early Access", children: actions)
    }
    
    private func updateEarlyAccessButton() {
        earlyAccessButton.setTitle(earlyAccessDuration.displayName, for: .normal)
        earlyAccessButton.menu = createEarlyAccessMenu()
    }
    
    @objc private func earlyAccessButtonTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.earlyAccessButton.backgroundColor = .systemGray2
            self.earlyAccessButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func earlyAccessButtonTouchUp() {
        UIView.animate(withDuration: 0.1) {
            self.earlyAccessButton.backgroundColor = NNColors.NNSystemBackground4
            self.earlyAccessButton.transform = .identity
        }
    }
    
    private func updateEarlyAccessButtonEnabledState() {
        if earlyAccessButton.isEnabled {
            earlyAccessButton.setTitleColor(.label, for: .normal)
            earlyAccessButton.backgroundColor = NNColors.NNSystemBackground4
        } else {
            earlyAccessButton.setTitleColor(.secondaryLabel, for: .normal)
            earlyAccessButton.backgroundColor = .systemGray4.withAlphaComponent(0.3)
        }
    }
}
