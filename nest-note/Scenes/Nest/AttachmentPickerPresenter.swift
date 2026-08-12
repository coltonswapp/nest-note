//
//  AttachmentPickerPresenter.swift
//  nest-note
//

import UIKit

/// Presents the nest-item multi-select flow capped for attachments (max 3).
enum AttachmentPickerPresenter {

    static func present(
        from presenter: UIViewController,
        selectedIds: [String],
        excludingHostId: String?,
        onComplete: @escaping ([String]) -> Void
    ) {
        let folderVC = ModifiedSelectFolderViewController(nestItemRepository: NestService.shared)
        folderVC.title = "Attach Items"
        folderVC.allowsEmptySelection = true
        folderVC.maxSelectionCount = AttachmentResolver.maxCount
        folderVC.hidesSelectAllButton = true
        if let excludingHostId {
            folderVC.excludedItemIds = [excludingHostId]
        }
        folderVC.setInitialSelectedItemIds(selectedIds)

        let nav = UINavigationController(rootViewController: folderVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }

        let coordinator = AttachmentPickerCoordinator(
            navigationController: nav,
            folderViewController: folderVC,
            onComplete: onComplete
        )
        folderVC.delegate = coordinator
        folderVC.onContinueTapped = { [weak coordinator] ids in
            coordinator?.handleContinue(with: ids)
        }
        folderVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: coordinator,
            action: #selector(AttachmentPickerCoordinator.showAboutAttachments)
        )
        folderVC.navigationItem.leftBarButtonItem?.accessibilityLabel = "About Attachments"
        folderVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: coordinator,
            action: #selector(AttachmentPickerCoordinator.cancel)
        )

        presenter.present(nav, animated: true) {
            presentAboutAttachmentsIfNeeded(from: nav)
        }
    }

    private static func presentAboutAttachmentsIfNeeded(from presenter: UIViewController) {
        guard AttachmentsIntroStore.shouldShow else { return }
        presentAboutAttachments(from: presenter)
    }

    fileprivate static func presentAboutAttachments(from presenter: UIViewController) {
        let introVC = IntroducingAttachmentsViewController()
        let introNav = UINavigationController(rootViewController: introVC)
        introNav.modalPresentationStyle = .pageSheet
        if let sheet = introNav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        introNav.presentationController?.delegate = introVC
        presenter.present(introNav, animated: true)
    }
}

private final class AttachmentPickerCoordinator: NSObject, ModifiedSelectFolderViewControllerDelegate {
    private weak var navigationController: UINavigationController?
    private weak var folderViewController: ModifiedSelectFolderViewController?
    private let onComplete: ([String]) -> Void
    /// Retain self while the picker is presented.
    private var selfRetain: AttachmentPickerCoordinator?
    private var isCheckingAccess = false

    init(
        navigationController: UINavigationController,
        folderViewController: ModifiedSelectFolderViewController,
        onComplete: @escaping ([String]) -> Void
    ) {
        self.navigationController = navigationController
        self.folderViewController = folderViewController
        self.onComplete = onComplete
        super.init()
        self.selfRetain = self
    }

    @objc func cancel() {
        navigationController?.dismiss(animated: true)
        selfRetain = nil
    }

    @objc func showAboutAttachments() {
        guard let presenter = navigationController else { return }
        AttachmentPickerPresenter.presentAboutAttachments(from: presenter)
    }

    func handleContinue(with ids: [String]) {
        // Clearing attachments stays available; applying a selection requires Pro.
        guard !ids.isEmpty else {
            finish(with: ids)
            navigationController?.dismiss(animated: true)
            return
        }

        guard !isCheckingAccess else { return }
        isCheckingAccess = true

        Task {
            let hasAccess = await SubscriptionService.shared.isFeatureAvailable(.attachments)
            await MainActor.run {
                self.isCheckingAccess = false
                guard hasAccess else {
                    self.presentPaywall()
                    return
                }
                self.finish(with: ids)
                self.navigationController?.dismiss(animated: true)
            }
        }
    }

    func finish(with ids: [String]) {
        let capped = Array(ids.prefix(AttachmentResolver.maxCount))
        onComplete(capped)
        selfRetain = nil
    }

    private func presentPaywall() {
        guard let presenter = navigationController?.topViewController ?? navigationController else { return }
        let paywall = FeatureInfoPaywallViewController()
        paywall.modalPresentationStyle = .pageSheet
        if let sheet = paywall.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        presenter.present(paywall, animated: true)
    }

    func modifiedSelectFolderViewController(
        _ controller: ModifiedSelectFolderViewController,
        didSelectFolder folderPath: String
    ) {
        let categoryVC = NestCategoryViewController(
            nestItemRepository: NestService.shared,
            initialCategory: folderPath,
            isEditOnlyMode: true
        )
        categoryVC.selectNestItemsDelegate = controller
        categoryVC.title = folderPath.components(separatedBy: "/").last ?? folderPath
        categoryVC.setSelectionLimit(
            controller.getCurrentSelectionLimit(),
            offersUpgrade: controller.maxSelectionCount == nil
        )
        categoryVC.setExcludedItemIds(controller.excludedItemIds)
        categoryVC.setHidesSelectAllButton(controller.hidesSelectAllButton)

        Task {
            let selectedItems = await controller.getCurrentSelectedItems()
            await MainActor.run {
                categoryVC.restoreSelectedItems(selectedItems)
                self.navigationController?.pushViewController(categoryVC, animated: true)
            }
        }
    }
}
