//
//  RoutineFrequencyViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 8/17/25.
//

import UIKit

protocol RoutineFrequencyViewControllerDelegate: AnyObject {
    func routineFrequencyViewController(_ controller: RoutineFrequencyViewController, didSelectFrequency frequency: String)
}

class RoutineFrequencyViewController: NNViewController {
    
    weak var delegate: RoutineFrequencyViewControllerDelegate?
    private let currentFrequency: String
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = NNImage.primaryLogo
        imageView.tintColor = NNColors.primary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h2
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.bodyL
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let titleStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()
    
    private let fieldLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .bodyM
        label.textColor = .lightGray
        return label
    }()
    
    private lazy var tagView: FrequencyTagView = {
        let view = FrequencyTagView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    private lazy var textField: NNTextField = {
        let field = NNTextField(showClearButton: true)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.delegate = self
        field.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        return field
    }()
    
    private let fieldStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }()
    
    private lazy var saveButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Save", titleColor: .white, fillStyle: .fill(NNColors.primaryAlt))
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        button.isEnabled = false // Disabled by default
        return button
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    init(currentFrequency: String = "Daily") {
        self.currentFrequency = currentFrequency
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.isNavigationBarHidden = true
        setupKeyboardAvoidance()
    }
    
    private func setupKeyboardAvoidance() {
        // Create a bottom constraint for the save button
        let bottomConstraint = saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        bottomConstraint.isActive = true
        
        // Setup keyboard avoidance
        setupKeyboardAvoidance(
            for: saveButton,
            bottomConstraint: bottomConstraint,
            defaultBottomSpacing: 16
        )
    }
    
    deinit {
        removeKeyboardAvoidance(for: saveButton)
    }
    
    override func setup() {
        titleLabel.text = "Routine Frequency"
        descriptionLabel.text = "Choose when you would like this routine to be completed."
        fieldLabel.text = "FREQUENCY"
        textField.placeholder = "Every Tuesday"
        textField.text = currentFrequency
        
        // Configure tag view with current frequency
        tagView.configure(with: currentFrequency)
        
        // Configure sheet presentation
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        
        // Set initial button state
        updateSaveButtonState()
    }
    
    override func addSubviews() {
        view.addSubview(stackView)
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(titleStack)
        stackView.addArrangedSubview(tagView)
        fieldStack.addArrangedSubview(fieldLabel)
        fieldStack.addArrangedSubview(textField)
        stackView.addArrangedSubview(fieldStack)
        view.addSubview(saveButton)
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            titleStack.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            titleStack.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            tagView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            
            textField.heightAnchor.constraint(equalToConstant: 55),
            textField.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            saveButton.heightAnchor.constraint(equalToConstant: 55)
        ])
    }
    
    @objc private func textFieldDidChange() {
        // Check if the current text matches any preset frequency
        let currentText = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let frequencies = ["Daily", "Nightly", "Every Morning", "Every Evening", "Tuesdays"]
        
        // Only update tag view if we have a selection that needs to be cleared
        if !frequencies.contains(currentText) && tagView.hasSelection {
            tagView.clearSelection()
        }
        
        updateSaveButtonState()
    }
    
    private func updateSaveButtonState() {
        let newValue = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let currentValue = currentFrequency.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Enable save button only if:
        // 1. The new value is not empty
        // 2. The new value is different from the current value
        saveButton.isEnabled = !newValue.isEmpty && newValue != currentValue
    }
    
    @objc private func saveButtonTapped() {
        guard let newValue = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !newValue.isEmpty else {
            return
        }
        
        Task {
            await MainActor.run {
                delegate?.routineFrequencyViewController(self, didSelectFrequency: newValue)
                dismiss(animated: true)
            }
        }
    }
}

extension RoutineFrequencyViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}

extension RoutineFrequencyViewController: FrequencyTagViewDelegate {
    func frequencyTagView(_ tagView: FrequencyTagView, didSelectFrequency frequency: String) {
        textField.text = frequency
        updateSaveButtonState()
    }
}

// MARK: - CenterAlignedCollectionViewFlowLayout

enum TagAlignment {
    case leading, center, trailing
}

class CenterAlignedCollectionViewFlowLayout: UICollectionViewFlowLayout {
    var tagAlignment: TagAlignment = .leading
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let superAttributes = super.layoutAttributesForElements(in: rect),
              let attributes = NSArray(array: superAttributes, copyItems: true) as? [UICollectionViewLayoutAttributes] else {
            return nil
        }
        
        let sectionsToHandle = Set(attributes.map { $0.indexPath.section })
        for section in sectionsToHandle {
            let sectionAttributes = attributes.filter { $0.indexPath.section == section }
            alignSection(attributes: sectionAttributes)
        }
        
        return attributes
    }
    
    private func alignSection(attributes: [UICollectionViewLayoutAttributes]) {
        guard let collectionView = collectionView else { return }
        
        var leftMargin: CGFloat = sectionInset.left
        var maxY: CGFloat = -1.0
        var rowAttributes: [UICollectionViewLayoutAttributes] = []
        
        for attribute in attributes {
            if attribute.frame.origin.y >= maxY {
                alignRow(rowAttributes, in: collectionView)
                rowAttributes.removeAll()
                leftMargin = sectionInset.left
            }
            
            attribute.frame.origin.x = leftMargin
            leftMargin += attribute.frame.width + minimumInteritemSpacing
            maxY = max(attribute.frame.maxY, maxY)
            rowAttributes.append(attribute)
        }
        
        alignRow(rowAttributes, in: collectionView)
    }
    
    private func alignRow(_ attributes: [UICollectionViewLayoutAttributes], in collectionView: UICollectionView) {
        guard !attributes.isEmpty else { return }
        
        let rowWidth = attributes.reduce(0) { $0 + $1.frame.width }
        let spacing = CGFloat(attributes.count - 1) * minimumInteritemSpacing
        let totalRowWidth = rowWidth + spacing
        
        let leftPadding: CGFloat
        switch tagAlignment {
        case .leading:
            leftPadding = sectionInset.left
        case .center:
            leftPadding = (collectionView.frame.width - totalRowWidth) / 2
        case .trailing:
            leftPadding = collectionView.frame.width - totalRowWidth - sectionInset.right
        }
        
        var offset = leftPadding
        
        for attribute in attributes {
            attribute.frame.origin.x = offset
            offset += attribute.frame.width + minimumInteritemSpacing
        }
    }
}

// MARK: - FrequencyTagView

protocol FrequencyTagViewDelegate: AnyObject {
    func frequencyTagView(_ tagView: FrequencyTagView, didSelectFrequency frequency: String)
}

class FrequencyTagView: UIView {
    weak var delegate: FrequencyTagViewDelegate?
    
    private let frequencies = ["Daily", "Nightly", "Every Morning", "Every Evening", "Tuesdays"]
    private var selectedFrequency: String?
    private var collectionView: UICollectionView!
    
    var hasSelection: Bool {
        return selectedFrequency != nil
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCollectionView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCollectionView() {
        let layout = CenterAlignedCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        
        collectionView = UICollectionView(frame: bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isScrollEnabled = false  // Disable scrolling since we want to show all content
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        collectionView.register(FrequencyTagCell.self, forCellWithReuseIdentifier: FrequencyTagCell.reuseIdentifier)
        
        addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Force initial layout calculation
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    func configure(with currentFrequency: String) {
        selectedFrequency = frequencies.contains(currentFrequency) ? currentFrequency : nil
        collectionView.reloadData()
        invalidateIntrinsicContentSize()
    }
    
    func clearSelection() {
        guard selectedFrequency != nil else { return }
        selectedFrequency = nil
        collectionView.reloadData()
    }
    
    override var intrinsicContentSize: CGSize {
        let contentSize = collectionView.collectionViewLayout.collectionViewContentSize
        return CGSize(width: contentSize.width, height: max(contentSize.height, 44))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Force collection view to layout first
        collectionView.layoutIfNeeded()
        // Then invalidate intrinsic content size after layout is complete
        DispatchQueue.main.async {
            self.invalidateIntrinsicContentSize()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            collectionView.reloadData()
        }
    }
}

// MARK: - UICollectionViewDataSource
extension FrequencyTagView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return frequencies.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FrequencyTagCell.reuseIdentifier,
            for: indexPath
        ) as! FrequencyTagCell
        
        let frequency = frequencies[indexPath.item]
        let isSelected = selectedFrequency == frequency
        
        cell.configure(title: frequency, isEnabled: isSelected)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension FrequencyTagView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let frequency = frequencies[indexPath.item]
        
        // Update selection
        let wasSelected = selectedFrequency == frequency
        selectedFrequency = wasSelected ? nil : frequency
        
        // Reload all visible cells to update appearance
        let visible = collectionView.indexPathsForVisibleItems
        if !visible.isEmpty {
            collectionView.reloadItems(at: visible)
        } else {
            collectionView.reloadData()
        }
        
        // Update layout
        invalidateIntrinsicContentSize()
        
        // Notify delegate if a frequency was selected
        if let selectedFrequency = selectedFrequency {
            delegate?.frequencyTagView(self, didSelectFrequency: selectedFrequency)
        }
        
        HapticsHelper.lightHaptic()
    }
}

// MARK: - FrequencyTagCell
private class FrequencyTagCell: UICollectionViewCell {
    static let reuseIdentifier = "FrequencyTagCell"
    
    private let titleLabel = UILabel()
    private var isEnabled: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.layer.cornerRadius = 16
        contentView.layer.borderWidth = 1.5
        // Leave contentView.translatesAutoresizingMaskIntoConstraints = true for cell autosizing
        
        titleLabel.font = .h5
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(title: String, isEnabled: Bool) {
        titleLabel.text = title
        self.isEnabled = isEnabled
        
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            if isEnabled {
                // Selected state - matching NNCategoryFilterView selected styling but with requested colors
                self.contentView.backgroundColor = NNColors.primary.withAlphaComponent(0.2)
                self.contentView.layer.borderColor = NNColors.primary.cgColor
                self.titleLabel.textColor = NNColors.primary
            } else {
                // Deselected state - matching NNCategoryFilterView deselected styling
                self.contentView.backgroundColor = NNColors.NNSystemBackground4.withAlphaComponent(0.5)
                self.contentView.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.3).cgColor
                self.titleLabel.textColor = .tertiaryLabel
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update colors when switching between light and dark mode
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Re-apply current state to update colors
            if let text = titleLabel.text {
                configure(title: text, isEnabled: isEnabled)
            }
        }
    }
}
