//
//  AttachmentStackView.swift
//  nest-note
//
//  Adapted from ImageStackView — stacked/collapsible attachment cards with optional glass plus.
//

import UIKit

protocol AttachmentStackViewDelegate: AnyObject {
    func attachmentStackView(_ stackView: AttachmentStackView, didTapItem item: any BaseItem)
    func attachmentStackViewDidTapPlus(_ stackView: AttachmentStackView)
    func attachmentStackView(_ stackView: AttachmentStackView, didChangeExpanded isExpanded: Bool)
    func attachmentStackView(_ stackView: AttachmentStackView, didRequestRemoveItem item: any BaseItem)
}

extension AttachmentStackViewDelegate {
    func attachmentStackView(_ stackView: AttachmentStackView, didChangeExpanded isExpanded: Bool) {}
    func attachmentStackView(_ stackView: AttachmentStackView, didRequestRemoveItem item: any BaseItem) {}
}

final class AttachmentStackView: UIView, UIGestureRecognizerDelegate, UIContextMenuInteractionDelegate {

    enum ExpansionDirection {
        case up, down, left, right

        var unit: CGPoint {
            switch self {
            case .up: return CGPoint(x: 0, y: -1)
            case .down: return CGPoint(x: 0, y: 1)
            case .left: return CGPoint(x: -1, y: 0)
            case .right: return CGPoint(x: 1, y: 0)
            }
        }
    }

    private enum Slot {
        case item(any BaseItem)
        case plus
    }

    // MARK: - Public
    weak var delegate: AttachmentStackViewDelegate?
    private(set) var isExpanded: Bool = false {
        didSet {
            guard oldValue != isExpanded else { return }
            delegate?.attachmentStackView(self, didChangeExpanded: isExpanded)
        }
    }

    // MARK: - Config
    private let stackSize: CGFloat
    private let plusButtonSize: CGFloat = 36
    private let paperclipButtonSize: CGFloat = 44
    private let expansionDirection: ExpansionDirection
    private var slots: [Slot] = []
    private var showsPlus: Bool = true
    /// When true, item cards offer a long-press "Remove" context menu.
    private var allowsRemoval: Bool = false

    // MARK: - UI
    private var cardContentViews: [UIView] = []
    private var stackContainerViews: [UIView] = []
    private var originalRotations: [CGFloat] = []
    private var baseCenterOffsets: [CGPoint] = []
    private var expandedTapZones: [UIView] = []
    private var collapseChevronButton: GlassIconButton?
    private var paperclipButton: AttachmentPaperclipButton?
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?

    // MARK: - Gestures / State
    private var panGesture: UIPanGestureRecognizer!
    private var currentTransitionProgress: CGFloat = 0.0
    /// Fitted center-to-origin distances along the expansion axis when fully open.
    private var fittedExpandedAxisOffsets: [CGFloat] = []
    /// Edge gap used for the current fitted layout (may compress in tight space).
    private var fittedInterElementGap: CGFloat = 12
    private var hasPlayedCloseThresholdHaptic = false
    /// True while an interactive pan started from the expanded state.
    private var isCollapsingPan = false
    private var isAnimatingRemoval = false
    private let maxOvershootPoints: CGFloat = 80
    private let maxCollapseOverscrollRotation: CGFloat = 15 * .pi / 180
    /// Progress at/below which a collapsing pan will commit to close on release.
    private let closeProgressThreshold: CGFloat = 0.5
    private let collapseChevronSize: CGFloat = 36
    /// Equal edge gap between chevron, cards, and plus when expanded.
    private let interElementGap: CGFloat = 12
    /// Card scale when fully expanded.
    private let expandedScale: CGFloat = 1.12

    // MARK: - Init
    init(stackSize: CGFloat = 88, expansionDirection: ExpansionDirection = .up) {
        self.stackSize = stackSize
        self.expansionDirection = expansionDirection
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.stackSize = 88
        self.expansionDirection = .up
        super.init(coder: coder)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        recomputeFittedExpandedAxisOffsets()
    }

    // MARK: - Public API

    /// Configures the stack. Pass `showsPlus: false` for read-only / sitter.
    /// Plus appears when there is already 1–2 attachments and `showsPlus` is true.
    /// Empty editable stacks show a dashed paperclip control for the first attach.
    func configure(items: [any BaseItem], showsPlus: Bool, allowsRemoval: Bool = false) {
        self.showsPlus = showsPlus
        self.allowsRemoval = allowsRemoval
        let nextSlots = Self.makeSlots(from: items, showsPlus: showsPlus)

        // Skip a hard rebuild when the stack already matches (e.g. after animated removal).
        if !isAnimatingRemoval, slotsMatch(nextSlots) {
            return
        }

        applySlots(nextSlots)
    }

    func setPreviewImage(_ image: UIImage?, forItemId itemId: String) {
        for (slotIndex, slot) in slots.enumerated() {
            guard case .item(let item) = slot, item.id == itemId else { continue }
            // cardContentViews are built in reversed slot order
            let visualIndex = slots.count - 1 - slotIndex
            guard visualIndex >= 0, visualIndex < cardContentViews.count,
                  let card = cardContentViews[visualIndex] as? AttachmentCardView else { return }
            card.setImage(image)
            return
        }
    }

    func expand() {
        // Keep containers interactive so long-press Remove menus still work when expanded.
        HapticsHelper.superLightHaptic()
        createExpandedTapZones()
        createCollapseChevron()
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.3,
            options: [.curveEaseInOut, .beginFromCurrentState]
        ) {
            self.applyAccordionTransform(progress: 1.0)
        }
    }

    func collapse() {
        removeExpandedTapZones()
        removeCollapseChevron()
        currentTransitionProgress = 0
        // Threshold haptic already played during pan when the close threshold was crossed.
        if !hasPlayedCloseThresholdHaptic {
            HapticsHelper.superLightHaptic()
        }
        hasPlayedCloseThresholdHaptic = false
        isCollapsingPan = false
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.3,
            options: [.curveEaseInOut, .beginFromCurrentState]
        ) {
            // Must use the same transform path as expand/pan — rotation-only
            // left translation/scale stuck when collapsing from a fully open stack.
            // Rotation is deferred until release; animate it in now with the collapse.
            self.applyAccordionTransform(progress: 0, appliesRotation: true)
        }
    }

    /// Collapses the accordion if currently expanded or mid-transition.
    func collapseIfNeeded() {
        guard isExpanded || currentTransitionProgress > 0.001 else { return }
        isExpanded = false
        collapse()
    }

    // MARK: - Setup
    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false

        widthConstraint = widthAnchor.constraint(equalToConstant: stackSize + 24)
        heightConstraint = heightAnchor.constraint(equalToConstant: stackSize + 24)
        NSLayoutConstraint.activate([widthConstraint!, heightConstraint!])

        setupPanGesture()
    }

    private func rebuild(with newSlots: [Slot]) {
        removeExpandedTapZones()
        stackContainerViews.forEach { $0.removeFromSuperview() }
        stackContainerViews.removeAll()
        cardContentViews.removeAll()
        originalRotations.removeAll()
        baseCenterOffsets.removeAll()
        fittedExpandedAxisOffsets.removeAll()
        slots = newSlots
        isExpanded = false
        currentTransitionProgress = 0
        hasPlayedCloseThresholdHaptic = false
        isCollapsingPan = false
        removeCollapseChevron()

        guard !slots.isEmpty else { return }
        setupStack()
        recomputeFittedExpandedAxisOffsets()
    }

    private func showPaperclipButton() {
        if paperclipButton == nil {
            let button = AttachmentPaperclipButton()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.accessibilityLabel = "Add attachment"
            button.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
            addSubview(button)
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: centerXAnchor),
                button.centerYAnchor.constraint(equalTo: centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: paperclipButtonSize),
                button.heightAnchor.constraint(equalToConstant: paperclipButtonSize)
            ])
            paperclipButton = button
        }
        paperclipButton?.isHidden = false
        paperclipButton?.alpha = 1
    }

    private func hidePaperclipButton() {
        paperclipButton?.isHidden = true
    }

    private func setupStack() {
        let rotations = computeInitialRotations(count: slots.count)
        // Reverse so first slot ends up on top visually.
        for (index, slot) in slots.reversed().enumerated() {
            let containerView = UIView()
            containerView.translatesAutoresizingMaskIntoConstraints = false

            let contentView: UIView
            switch slot {
            case .item(let item):
                containerView.layer.shadowColor = UIColor.black.cgColor
                containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
                containerView.layer.shadowOpacity = 0.25
                containerView.layer.shadowRadius = 4

                let card = AttachmentCardView()
                card.configure(with: item)
                card.translatesAutoresizingMaskIntoConstraints = false
                contentView = card

                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
                card.addGestureRecognizer(tapGesture)
                card.isUserInteractionEnabled = true
                if allowsRemoval {
                    card.addInteraction(UIContextMenuInteraction(delegate: self))
                }

            case .plus:
                let plusButton = GlassIconButton(
                    systemName: "plus",
                    pointSize: 16,
                    weight: .semibold,
                    tintColor: NNColors.primary,
                    size: plusButtonSize,
                    accessibilityLabel: "Add attachment"
                )
                // Glass fallback / card-shadow restore can leave a heavy drop under the
                // plus — keep it flat against the sheet.
                plusButton.layer.shadowOpacity = 0
                plusButton.layer.shadowRadius = 0
                plusButton.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
                contentView = plusButton
            }

            containerView.addSubview(contentView)
            addSubview(containerView)
            cardContentViews.append(contentView)
            stackContainerViews.append(containerView)

            let offsetX = CGFloat(index) * 3
            let offsetY = CGFloat(index) * -3
            let rotation = rotations[index]

            var constraints: [NSLayoutConstraint] = [
                containerView.widthAnchor.constraint(equalToConstant: stackSize),
                containerView.heightAnchor.constraint(equalToConstant: stackSize),
                containerView.centerXAnchor.constraint(equalTo: centerXAnchor, constant: offsetX),
                containerView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: offsetY),
                contentView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                contentView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ]

            if case .plus = slot {
                constraints.append(contentsOf: [
                    contentView.widthAnchor.constraint(equalToConstant: plusButtonSize),
                    contentView.heightAnchor.constraint(equalToConstant: plusButtonSize)
                ])
            } else {
                constraints.append(contentsOf: [
                    contentView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
                    contentView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
                ])
            }

            NSLayoutConstraint.activate(constraints)

            containerView.transform = CGAffineTransform(rotationAngle: rotation)
            originalRotations.append(rotation)
            baseCenterOffsets.append(CGPoint(x: offsetX, y: offsetY))
        }
    }

    private func setupPanGesture() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        // Don't cancel touches so taps / context menus still work on cards.
        panGesture.cancelsTouchesInView = false
        addGestureRecognizer(panGesture)
    }

    // MARK: - Gestures
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard !isAnimatingRemoval, stackContainerViews.count > 1 else { return }

        let container = superview ?? self
        let translation = gesture.translation(in: container)
        let velocity = gesture.velocity(in: container)

        let axis = expansionDirection.unit
        let projectedTranslation = translation.x * axis.x + translation.y * axis.y
        let projectedVelocity = velocity.x * axis.x + velocity.y * axis.y

        switch gesture.state {
        case .began:
            currentTransitionProgress = isExpanded ? 1.0 : 0.0
            isCollapsingPan = isExpanded
            hasPlayedCloseThresholdHaptic = false
        case .changed:
            let maxDistance = max(fittedExpandedAxisOffsets.last ?? 0, 1)

            var newProgress: CGFloat
            if isExpanded {
                newProgress = 1.0 + (projectedTranslation / maxDistance)
            } else {
                newProgress = projectedTranslation / maxDistance
            }

            currentTransitionProgress = max(0.0, min(1.0, newProgress))
            updateCloseThresholdHaptic(for: currentTransitionProgress)

            var displayProgress = newProgress
            var collapseOverscrollExtraRotation: CGFloat = 0
            if newProgress > 1.0 {
                let delta = newProgress - 1.0
                let maxOvershootProgress = maxOvershootPoints / maxDistance
                let banded = rubberBand(delta: delta, maxOvershoot: maxOvershootProgress)
                displayProgress = 1.0 + banded
            } else if newProgress < 0.0, !isCollapsingPan {
                // Overscroll twist only when expanding past collapsed; collapse pans
                // keep cards upright until release.
                displayProgress = 0.0
                let delta = -newProgress
                let normalized = rubberBand(delta: delta, maxOvershoot: 1.0)
                collapseOverscrollExtraRotation = normalized * maxCollapseOverscrollRotation
            } else if newProgress < 0.0 {
                displayProgress = 0.0
            }

            applyAccordionTransform(
                progress: displayProgress,
                overscrollExtraRotation: collapseOverscrollExtraRotation,
                // Keep cards square while dragging closed; rotate only on release.
                appliesRotation: !isCollapsingPan
            )

        case .ended, .cancelled:
            let velocityThreshold: CGFloat = 500
            let shouldExpand: Bool
            if abs(projectedVelocity) > velocityThreshold {
                shouldExpand = projectedVelocity > 0
            } else {
                shouldExpand = currentTransitionProgress > closeProgressThreshold
            }
            completeTransition(shouldExpand: shouldExpand)
            isCollapsingPan = false
        default:
            break
        }
    }

    private func updateCloseThresholdHaptic(for progress: CGFloat) {
        guard isCollapsingPan else { return }
        if progress <= closeProgressThreshold {
            guard !hasPlayedCloseThresholdHaptic else { return }
            hasPlayedCloseThresholdHaptic = true
            HapticsHelper.superLightHaptic()
        } else {
            // Crossing back open re-arms so another collapse drag feels the threshold.
            hasPlayedCloseThresholdHaptic = false
        }
    }

    /// Only claim pans that are clearly along the accordion axis so vertical
    /// sheet dismiss / detent drag is not captured.
    /// Overrides `UIView.gestureRecognizerShouldBegin` (also used via `UIGestureRecognizerDelegate`).
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        guard !isAnimatingRemoval, stackContainerViews.count > 1 else { return false }

        let view = superview ?? self
        let translation = pan.translation(in: view)
        let velocity = pan.velocity(in: view)
        let axis = expansionDirection.unit

        let translationAlong = abs(translation.x * axis.x + translation.y * axis.y)
        let translationAcross = abs(translation.x * -axis.y + translation.y * axis.x)
        let velocityAlong = abs(velocity.x * axis.x + velocity.y * axis.y)
        let velocityAcross = abs(velocity.x * -axis.y + velocity.y * axis.x)

        // Prefer whichever signal is stronger at recognition time.
        if translationAlong + translationAcross > 6 {
            return translationAlong > translationAcross
        }
        return velocityAlong > velocityAcross && velocityAlong > 80
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Never share with the sheet's dismiss / detent pan.
        false
    }

    // MARK: - Actions
    @objc private func plusButtonTapped() {
        delegate?.attachmentStackViewDidTapPlus(self)
    }

    @objc private func collapseChevronTapped() {
        guard isExpanded else { return }
        isExpanded = false
        collapse()
    }

    /// Drops the card out, restacks what remains, then notifies the delegate.
    private func performRemoval(of item: any BaseItem) {
        guard !isAnimatingRemoval else { return }

        guard let slotIndex = slots.firstIndex(where: {
            if case .item(let candidate) = $0 { return candidate.id == item.id }
            return false
        }) else {
            delegate?.attachmentStackView(self, didRequestRemoveItem: item)
            return
        }

        let visualIndex = slots.count - 1 - slotIndex
        guard visualIndex >= 0, visualIndex < stackContainerViews.count else {
            delegate?.attachmentStackView(self, didRequestRemoveItem: item)
            return
        }

        isAnimatingRemoval = true
        let removingContainer = stackContainerViews[visualIndex]
        let remainingItems: [any BaseItem] = slots.compactMap {
            guard case .item(let candidate) = $0, candidate.id != item.id else { return nil }
            return candidate
        }
        let nextSlots = Self.makeSlots(from: remainingItems, showsPlus: showsPlus)

        removeExpandedTapZones()
        removeCollapseChevron()
        isExpanded = false
        currentTransitionProgress = 0
        HapticsHelper.lightHaptic()

        // Drop the removed card while the rest settle back into a stack.
        UIView.animate(
            withDuration: 0.38,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState]
        ) {
            removingContainer.transform = CGAffineTransform(translationX: 10, y: 150)
                .rotated(by: 14 * .pi / 180)
                .scaledBy(x: 0.88, y: 0.88)
            removingContainer.alpha = 0
            removingContainer.layer.shadowOpacity = 0
        }

        UIView.animate(
            withDuration: 0.45,
            delay: 0.04,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.35,
            options: [.curveEaseInOut, .beginFromCurrentState]
        ) {
            self.applyAccordionTransform(
                progress: 0,
                appliesRotation: true,
                excludingVisualIndex: visualIndex
            )
        } completion: { [weak self] _ in
            guard let self else { return }
            removingContainer.removeFromSuperview()
            self.applySlots(nextSlots)
            if nextSlots.isEmpty, self.showsPlus {
                self.paperclipButton?.alpha = 0
                UIView.animate(withDuration: 0.22) {
                    self.paperclipButton?.alpha = 1
                }
            }
            self.isAnimatingRemoval = false
            self.delegate?.attachmentStackView(self, didRequestRemoveItem: item)
        }
    }

    private static func makeSlots(from items: [any BaseItem], showsPlus: Bool) -> [Slot] {
        let capped = Array(items.prefix(AttachmentResolver.maxCount))
        var nextSlots: [Slot] = capped.map { .item($0) }
        if showsPlus && capped.count >= 1 && capped.count <= 2 {
            nextSlots.append(.plus)
        }
        return nextSlots
    }

    private func slotsMatch(_ nextSlots: [Slot]) -> Bool {
        // Empty never "matches" — otherwise the first configure([], ...) early-returns
        // before the dashed paperclip is created.
        guard !slots.isEmpty, !nextSlots.isEmpty, slots.count == nextSlots.count else {
            return false
        }
        for (lhs, rhs) in zip(slots, nextSlots) {
            switch (lhs, rhs) {
            case (.plus, .plus):
                continue
            case (.item(let a), .item(let b)) where a.id == b.id:
                continue
            default:
                return false
            }
        }
        return true
    }

    private func applySlots(_ nextSlots: [Slot]) {
        if nextSlots.isEmpty {
            rebuild(with: [])
            if showsPlus {
                showPaperclipButton()
                isHidden = false
                widthConstraint?.constant = paperclipButtonSize
                heightConstraint?.constant = paperclipButtonSize
            } else {
                hidePaperclipButton()
                isHidden = true
                widthConstraint?.constant = 0
                heightConstraint?.constant = 0
            }
            return
        }

        hidePaperclipButton()
        rebuild(with: nextSlots)
        isHidden = false
        widthConstraint?.constant = stackSize + 24
        heightConstraint?.constant = stackSize + 24
    }

    @objc private func cardTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view,
              let index = cardContentViews.firstIndex(of: view),
              index < slots.count else { return }

        let slot = Array(slots.reversed())[index]

        if case .plus = slot {
            delegate?.attachmentStackViewDidTapPlus(self)
            return
        }

        if isExpanded {
            if case .item(let item) = slot {
                delegate?.attachmentStackView(self, didTapItem: item)
            }
        } else if stackContainerViews.count > 1 {
            isExpanded = true
            expand()
        } else if case .item(let item) = slot {
            delegate?.attachmentStackView(self, didTapItem: item)
        }
    }

    // MARK: - Internals
    private func completeTransition(shouldExpand: Bool) {
        if shouldExpand && !isExpanded {
            isExpanded = true
            expand()
        } else if !shouldExpand && isExpanded {
            isExpanded = false
            collapse()
        } else {
            let targetProgress: CGFloat = isExpanded ? 1.0 : 0.0
            // Snapping back open keeps cards upright; committed close goes through
            // collapse(), which re-enables rotation on release.
            if targetProgress >= 1.0 {
                hasPlayedCloseThresholdHaptic = false
                if collapseChevronButton == nil {
                    createCollapseChevron()
                }
            }
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3,
                options: .curveEaseInOut
            ) {
                self.applyAccordionTransform(
                    progress: targetProgress,
                    appliesRotation: !self.isCollapsingPan
                )
            }
        }
    }

    private func applyAccordionTransform(
        progress: CGFloat,
        overscrollExtraRotation: CGFloat = 0,
        appliesRotation: Bool = true,
        excludingVisualIndex: Int? = nil
    ) {
        let clamped = max(0.0, min(1.0, progress))
        let scale = 1.0 + (expandedScale - 1.0) * clamped
        let axis = expansionDirection.unit
        // Pull the home element (often the smaller plus) flush toward the trailing edge.
        let trailing = trailingAlignOffset(scale: scale, progress: clamped)

        for (index, container) in stackContainerViews.enumerated() {
            if let excludingVisualIndex, index == excludingVisualIndex { continue }

            let axisOffset = index < fittedExpandedAxisOffsets.count
                ? fittedExpandedAxisOffsets[index]
                : 0
            let alignX = -baseCenterOffsets[index].x * clamped
            let alignY = -baseCenterOffsets[index].y * clamped
            let translateX = axis.x * axisOffset * progress + alignX + trailing.x
            let translateY = axis.y * axisOffset * progress + alignY + trailing.y

            var rotationAngle: CGFloat = 0
            if appliesRotation {
                rotationAngle = originalRotations[index] * (1.0 - clamped)
                if overscrollExtraRotation > 0 {
                    let sign: CGFloat = originalRotations[index] >= 0 ? 1 : -1
                    rotationAngle += overscrollExtraRotation * sign
                }
            }

            container.transform = CGAffineTransform(translationX: translateX, y: translateY)
                .rotated(by: rotationAngle)
                .scaledBy(x: scale, y: scale)
        }

        if let chevron = collapseChevronButton {
            chevron.alpha = clamped
            chevron.isUserInteractionEnabled = clamped > closeProgressThreshold
        }
    }

    private func createExpandedTapZones() {
        removeExpandedTapZones()
        guard let overlayParent = superview else { return }
        recomputeFittedExpandedAxisOffsets()

        let axis = expansionDirection.unit

        for (index, _) in cardContentViews.enumerated() {
            let tapZone = UIView()
            tapZone.backgroundColor = .clear
            tapZone.translatesAutoresizingMaskIntoConstraints = false
            tapZone.tag = index

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(expandedCardTapped(_:)))
            tapZone.addGestureRecognizer(tapGesture)

            let panGestureForZone = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            panGestureForZone.delegate = self
            panGestureForZone.cancelsTouchesInView = false
            tapZone.addGestureRecognizer(panGestureForZone)

            if allowsRemoval, case .item = Array(slots.reversed())[index] {
                tapZone.addInteraction(UIContextMenuInteraction(delegate: self))
            }

            overlayParent.addSubview(tapZone)
            expandedTapZones.append(tapZone)

            let axisOffset = index < fittedExpandedAxisOffsets.count
                ? fittedExpandedAxisOffsets[index]
                : 0
            let trailing = trailingAlignOffset(scale: expandedScale, progress: 1)
            let alignX = -baseCenterOffsets[index].x
            let alignY = -baseCenterOffsets[index].y
            let tx = axis.x * axisOffset + alignX + trailing.x
            let ty = axis.y * axisOffset + alignY + trailing.y
            let hitSize = visualSize(at: index) * expandedScale

            NSLayoutConstraint.activate([
                tapZone.centerXAnchor.constraint(equalTo: centerXAnchor, constant: tx),
                tapZone.centerYAnchor.constraint(equalTo: centerYAnchor, constant: ty),
                tapZone.widthAnchor.constraint(equalToConstant: hitSize),
                tapZone.heightAnchor.constraint(equalToConstant: hitSize)
            ])
        }
        overlayParent.bringSubviewToFront(self)
        for zone in expandedTapZones {
            overlayParent.bringSubviewToFront(zone)
        }
    }

    private func removeExpandedTapZones() {
        for view in expandedTapZones { view.removeFromSuperview() }
        expandedTapZones.removeAll()
    }

    private func createCollapseChevron() {
        removeCollapseChevron()
        guard stackContainerViews.count > 1, let overlayParent = superview else { return }
        recomputeFittedExpandedAxisOffsets()

        let symbolName: String
        switch expansionDirection {
        case .left: symbolName = "chevron.right"
        case .right: symbolName = "chevron.left"
        case .up: symbolName = "chevron.down"
        case .down: symbolName = "chevron.up"
        }

        let button = GlassIconButton(
            systemName: symbolName,
            pointSize: 12,
            weight: .semibold,
            tintColor: .secondaryLabel,
            size: collapseChevronSize,
            accessibilityLabel: "Close attachments"
        )
        button.addTarget(self, action: #selector(collapseChevronTapped), for: .touchUpInside)
        button.alpha = 0
        overlayParent.addSubview(button)
        collapseChevronButton = button

        let point = collapseChevronCenterOffset()
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: collapseChevronSize),
            button.heightAnchor.constraint(equalToConstant: collapseChevronSize),
            button.centerXAnchor.constraint(equalTo: centerXAnchor, constant: point.x),
            button.centerYAnchor.constraint(equalTo: centerYAnchor, constant: point.y)
        ])

        overlayParent.bringSubviewToFront(button)
        UIView.animate(withDuration: 0.25, delay: 0.05, options: .curveEaseOut) {
            button.alpha = 1
        }
    }

    private func removeCollapseChevron() {
        collapseChevronButton?.removeFromSuperview()
        collapseChevronButton = nil
    }

    @objc private func expandedCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, view.tag < slots.count else { return }
        let slot = Array(slots.reversed())[view.tag]
        switch slot {
        case .item(let item):
            delegate?.attachmentStackView(self, didTapItem: item)
        case .plus:
            delegate?.attachmentStackViewDidTapPlus(self)
        }
    }

    // MARK: - UIContextMenuInteractionDelegate

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard allowsRemoval, let item = itemForContextMenu(interaction) else { return nil }

        return UIContextMenuConfiguration(identifier: item.id as NSCopying, previewProvider: nil) { [weak self] _ in
            let remove = UIAction(
                title: "Remove",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.performRemoval(of: item)
            }
            return UIMenu(children: [remove])
        }
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        targetedPreview(for: interaction)
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        targetedPreview(for: interaction)
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        setStackShadowsHidden(true)
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        animator?.addCompletion { [weak self] in
            self?.setStackShadowsHidden(false)
        }
    }

    private func setStackShadowsHidden(_ hidden: Bool) {
        let visualSlots = Array(slots.reversed())
        for (index, container) in stackContainerViews.enumerated() {
            // Only attachment cards get the stack drop shadow — never the plus.
            guard index < visualSlots.count, case .item = visualSlots[index] else {
                container.layer.shadowOpacity = 0
                continue
            }
            container.layer.shadowOpacity = hidden ? 0 : 0.25
        }
    }

    /// Preview only the rounded card face — excludes the parent container's drop shadow
    /// from the context-menu lift mask.
    private func targetedPreview(for interaction: UIContextMenuInteraction) -> UITargetedPreview? {
        guard let card = previewCard(for: interaction) else { return nil }
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(
            roundedRect: card.bounds,
            cornerRadius: card.layer.cornerRadius
        )
        // Empty path suppresses the default soft platter shadow that otherwise
        // follows the (larger) shadow bounds of the stack container.
        parameters.shadowPath = UIBezierPath()
        return UITargetedPreview(view: card, parameters: parameters)
    }

    private func previewCard(for interaction: UIContextMenuInteraction) -> AttachmentCardView? {
        if let card = interaction.view as? AttachmentCardView {
            return card
        }
        // Expanded tap zone — resolve the matching card by visual index.
        if let zone = interaction.view, zone.tag < cardContentViews.count {
            return cardContentViews[zone.tag] as? AttachmentCardView
        }
        return nil
    }

    private func itemForContextMenu(_ interaction: UIContextMenuInteraction) -> (any BaseItem)? {
        if let card = interaction.view as? AttachmentCardView {
            return card.boundItem
        }
        // Expanded tap zone — tag maps to reversed visual index.
        if let zone = interaction.view, zone.tag < slots.count {
            if case .item(let item) = Array(slots.reversed())[zone.tag] {
                return item
            }
        }
        return nil
    }

    /// Visual size of the element at a reversed/visual stack index (for equal edge gaps).
    private func visualSize(at index: Int) -> CGFloat {
        guard index >= 0, index < slots.count else { return stackSize }
        switch Array(slots.reversed())[index] {
        case .item: return stackSize
        case .plus: return plusButtonSize
        }
    }

    private func collapseChevronCenterOffset() -> CGPoint {
        guard !fittedExpandedAxisOffsets.isEmpty else { return .zero }
        let outermost = fittedExpandedAxisOffsets.count - 1
        let cardOffset = fittedExpandedAxisOffsets[outermost]
        let lastHalf = visualSize(at: outermost) * expandedScale / 2
        let outward = lastHalf + fittedInterElementGap + collapseChevronSize / 2
        let axis = expansionDirection.unit
        let trailing = trailingAlignOffset(scale: expandedScale, progress: 1)
        let alignX = -baseCenterOffsets[outermost].x
        let alignY = -baseCenterOffsets[outermost].y
        return CGPoint(
            x: axis.x * (cardOffset + outward) + alignX + trailing.x,
            y: axis.y * (cardOffset + outward) + alignY + trailing.y
        )
    }

    /// Shifts the expanded fan toward the trailing/home edge so a smaller plus
    /// doesn't sit inset from where a full-size card would land.
    private func trailingAlignOffset(scale: CGFloat, progress: CGFloat) -> CGPoint {
        guard !stackContainerViews.isEmpty else { return .zero }
        let homeSize = visualSize(at: 0) * scale
        let referenceSize = stackSize * scale
        // Half the size difference (plus is smaller than a card) plus half of the
        // stack view's extra width padding (stackSize + 24).
        let nudge = max(0, (referenceSize - homeSize) / 2) + 12
        let amount = nudge * max(0, min(1, progress))
        let axis = expansionDirection.unit
        return CGPoint(x: -axis.x * amount, y: -axis.y * amount)
    }

    private func availableExpansionDistance() -> CGFloat {
        guard let parent = superview else { return .greatestFiniteMagnitude }
        let safe = parent.safeAreaInsets
        let margin: CGFloat = 40
        let centerInParent = convert(CGPoint(x: bounds.midX, y: bounds.midY), to: parent)
        switch expansionDirection {
        case .up:
            return max(0, centerInParent.y - safe.top - margin)
        case .down:
            let bottomBound = parent.bounds.height - safe.bottom
            return max(0, bottomBound - centerInParent.y - margin)
        case .left:
            return max(0, centerInParent.x - safe.left - margin)
        case .right:
            let rightBound = parent.bounds.width - safe.right
            return max(0, rightBound - centerInParent.x - margin)
        }
    }

    private func recomputeFittedExpandedAxisOffsets() {
        let count = stackContainerViews.count
        guard count > 0 else {
            fittedExpandedAxisOffsets = []
            fittedInterElementGap = interElementGap
            return
        }

        let sizes = (0..<count).map { visualSize(at: $0) * expandedScale }
        // From home center to far edge of chevron: half of home + remaining sizes + gaps + chevron.
        let sizesExtent = sizes[0] / 2 + sizes.dropFirst().reduce(0, +)
        // Gaps between every adjacent pair of stack elements, plus one before the chevron.
        let gapCount = count
        let idealExtent = sizesExtent + CGFloat(gapCount) * interElementGap + collapseChevronSize
        let available = availableExpansionDistance()

        var gap = interElementGap
        if idealExtent > available, gapCount > 0 {
            let minGap: CGFloat = 4
            let sizeAndChevron = sizesExtent + collapseChevronSize
            let remainingForGaps = max(CGFloat(gapCount) * minGap, available - sizeAndChevron)
            gap = remainingForGaps / CGFloat(gapCount)
        }
        fittedInterElementGap = gap

        var centers = [CGFloat](repeating: 0, count: count)
        for i in 1..<count {
            centers[i] = centers[i - 1] + sizes[i - 1] / 2 + gap + sizes[i] / 2
        }
        fittedExpandedAxisOffsets = centers
    }

    private func computeInitialRotations(count: Int) -> [CGFloat] {
        guard count > 0 else { return [] }
        // A lone attachment (+ optional plus) shouldn't fan — tilt looks odd with one card.
        let itemCount = slots.reduce(0) { partial, slot in
            if case .item = slot { return partial + 1 }
            return partial
        }
        if itemCount <= 1 {
            return Array(repeating: 0, count: count)
        }

        // Visual order matches setupStack (slots reversed). Deterministic jitter from
        // item id so rebuilds don't jump, but angles feel casually tossed.
        let visualSlots = Array(slots.reversed())
        return (0..<count).map { index in
            let slot = index < visualSlots.count ? visualSlots[index] : .plus
            if case .plus = slot { return 0 }

            let seedSource: String
            if case .item(let item) = slot {
                seedSource = item.id
            } else {
                seedSource = "\(index)"
            }
            let hash = seedSource.unicodeScalars.reduce(into: 0) { partial, scalar in
                partial = partial &* 31 &+ Int(scalar.value)
            }
            let unit = CGFloat(abs(hash % 1000)) / 1000.0
            let magnitude = 0.16 + unit * 0.28 // ~9°–25°
            let sign: CGFloat = (hash & 1) == 0 ? -1 : 1
            // Nudge away from a strict alternate pattern.
            let flip: CGFloat = (abs(hash) % 5 == 0) ? -1 : 1
            return magnitude * sign * flip
        }
    }

    private func rubberBand(delta: CGFloat, maxOvershoot: CGFloat) -> CGFloat {
        guard delta > 0 else { return 0 }
        let k: CGFloat = 0.6
        let eased = (delta * k) / (delta * k + 1.0)
        return maxOvershoot * min(1.0, max(0.0, eased))
    }
}

// MARK: - Paperclip Button

/// Small dashed-rectangle control for adding the first attachment.
private final class AttachmentPaperclipButton: UIControl {
    private let dashedBorder = CAShapeLayer()
    private let iconView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let cornerRadius: CGFloat = 10
        dashedBorder.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerRadius: cornerRadius
        ).cgPath
        dashedBorder.frame = bounds
        layer.cornerRadius = cornerRadius
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        updateColors()
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.alpha = self.isHighlighted ? 0.7 : 1
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.96, y: 0.96)
                    : .identity
            }
        }
    }

    private func setup() {
        backgroundColor = .clear
        layer.cornerCurve = .continuous
        clipsToBounds = true

        dashedBorder.fillColor = nil
        dashedBorder.lineWidth = 1.25
        dashedBorder.lineDashPattern = [5, 4]
        layer.addSublayer(dashedBorder)

        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        iconView.image = UIImage(systemName: "paperclip", withConfiguration: config)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateColors()
    }

    private func updateColors() {
        let stroke = UIColor.tertiaryLabel.resolvedColor(with: traitCollection)
        dashedBorder.strokeColor = stroke.withAlphaComponent(0.35).cgColor
        iconView.tintColor = .secondaryLabel
    }
}

// MARK: - Card Views

/// Mini waterfall-style card for the attachment stack — same layout language as
/// `WaterfallGridCell`, constrained to a square with scaled-down type.
private final class AttachmentCardView: UIView {
    private enum LayoutStyle {
        case standard
        case place
    }

    private static let contentInset: CGFloat = 8
    private static let stackSpacing: CGFloat = 3
    private static let titleFontSize: CGFloat = 11
    private static let contentFontSize: CGFloat = 9
    private static let cornerRadius: CGFloat = 12
    private static let thumbnailCornerRadius: CGFloat = 6

    private(set) var boundItem: (any BaseItem)?
    private let thumbnailImageView = UIImageView()
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let textStack = UIStackView()

    private var layoutStyle: LayoutStyle = .standard
    private var standardConstraints: [NSLayoutConstraint] = []
    private var placeConstraints: [NSLayoutConstraint] = []
    private var thumbnailHeightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        backgroundColor = Self.cardSurfaceBackground()
        applyCardBorder()
    }

    private func setup() {
        backgroundColor = Self.cardSurfaceBackground()
        layer.cornerRadius = Self.cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true
        applyCardBorder()

        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = Self.thumbnailCornerRadius
        thumbnailImageView.layer.cornerCurve = .continuous
        thumbnailImageView.backgroundColor = .tertiarySystemFill
        thumbnailImageView.isHidden = true

        titleLabel.font = .systemFont(ofSize: Self.titleFontSize, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        contentLabel.font = .systemFont(ofSize: Self.contentFontSize, weight: .regular)
        contentLabel.textColor = .secondaryLabel
        contentLabel.numberOfLines = 3
        contentLabel.lineBreakMode = .byTruncatingTail

        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = Self.stackSpacing
        textStack.alignment = .fill
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(contentLabel)

        addSubview(thumbnailImageView)
        addSubview(textStack)

        thumbnailHeightConstraint = thumbnailImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.42)

        standardConstraints = [
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: Self.contentInset),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.contentInset),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.contentInset),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Self.contentInset)
        ]

        placeConstraints = [
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: Self.contentInset),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.contentInset),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.contentInset),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: thumbnailImageView.topAnchor, constant: -6),

            thumbnailImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.contentInset),
            thumbnailImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.contentInset),
            thumbnailImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.contentInset),
            thumbnailHeightConstraint!
        ]

        applyLayoutStyle(.standard)
    }

    func configure(with item: any BaseItem) {
        boundItem = item
        let preview = Self.preview(for: item)
        titleLabel.text = preview.title
        contentLabel.text = preview.content
        contentLabel.isHidden = preview.content.isEmpty

        let style: LayoutStyle = item.type == .place ? .place : .standard
        applyLayoutStyle(style)

        if style == .place {
            thumbnailImageView.isHidden = false
            contentLabel.numberOfLines = 2
        } else {
            thumbnailImageView.isHidden = true
            thumbnailImageView.image = nil
            contentLabel.numberOfLines = 3
        }
    }

    func setImage(_ image: UIImage?) {
        guard layoutStyle == .place else { return }
        thumbnailImageView.image = image
        thumbnailImageView.isHidden = false
    }

    private func applyLayoutStyle(_ style: LayoutStyle) {
        layoutStyle = style
        NSLayoutConstraint.deactivate(standardConstraints + placeConstraints)
        NSLayoutConstraint.activate(style == .place ? placeConstraints : standardConstraints)
    }

    private func applyCardBorder() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        // Dark mode: a visible edge so stacked cards separate without relying on shadows.
        // Light mode: hairline only — drop shadows already define the stack.
        layer.borderColor = Self.cardBorderColor().resolvedColor(with: traitCollection).cgColor
        layer.borderWidth = isDark ? 1 : 1 / traitCollection.displayScale
    }

    private static func cardSurfaceBackground() -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white
        }
    }

    private static func cardBorderColor() -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.18)
                : UIColor.black.withAlphaComponent(0.07)
        }
    }

    private static func preview(for item: any BaseItem) -> (title: String, content: String) {
        switch item {
        case let place as PlaceItem:
            return (place.alias ?? place.title, place.address)
        case let routine as RoutineItem:
            return (
                routine.title,
                WaterfallGridCell.routinePreviewText(
                    for: routine.routineActions,
                    emptyFallback: routine.frequency ?? "Routine"
                )
            )
        case let contact as ContactItem:
            return (contact.title, contact.content)
        case let entry as NoteItem:
            return (entry.title, entry.content)
        case let unknown as UnknownItem:
            return (unknown.title, "Type: \(unknown.originalTypeString)")
        default:
            return (item.title, "")
        }
    }
}
