import UIKit

class CompleteSitterSessionRequestViewController: NNViewController {

    // MARK: - Properties

    private let inviteCode: String
    private var placeholderSession: SessionItem
    private let invite: Invite

    private var editSessionVC: EditSessionViewController!

    // MARK: - Lifecycle

    init(inviteCode: String, placeholderSession: SessionItem, invite: Invite) {
        self.inviteCode = inviteCode
        self.placeholderSession = placeholderSession
        self.invite = invite
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        // Hide navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)

        // Sitter info is already in placeholderSession.assignedSitter
        setupEditSessionViewController()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure navigation bar stays hidden
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore navigation bar when leaving this screen
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup

    private func setupEditSessionViewController() {
        // Embed EditSessionViewController as a child
        editSessionVC = EditSessionViewController(sessionItem: placeholderSession)
        editSessionVC.delegate = self
        editSessionVC.isCompletingRequest = true  // Enable completion mode

        addChild(editSessionVC)
        view.addSubview(editSessionVC.view)
        editSessionVC.view.frame = view.bounds
        editSessionVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        editSessionVC.didMove(toParent: self)
    }

    // MARK: - Actions

    private func showSuccessAndDismiss() {
        let alert = UIAlertController(
            title: "Session Created!",
            message: "The session has been added to your nest and the sitter has been notified.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
            // Dismiss all the way back to home
            self?.presentingViewController?.dismiss(animated: true)
        })

        present(alert, animated: true)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - EditSessionViewControllerDelegate

extension CompleteSitterSessionRequestViewController: EditSessionViewControllerDelegate {
    func editSessionViewController(_ controller: EditSessionViewController, didCreateSession session: SessionItem) {
        // Parent completed the form - now accept the request
        Task {
            do {
                // Get sitter info from the session's assignedSitter (already populated)
                guard let assignedSitter = session.assignedSitter else {
                    throw SessionError.sessionNotFound
                }

                let sitterInfo = (
                    name: assignedSitter.name,
                    email: assignedSitter.email,
                    userID: assignedSitter.userID ?? invite.createdBy
                )

                try await SessionService.shared.acceptSitterSessionRequest(
                    inviteCode: inviteCode,
                    completedSession: session,
                    sitterInfo: sitterInfo
                )

                await MainActor.run {
                    // Stop loading button with success animation
                    self.editSessionVC.saveButton.stopLoading(withSuccess: true)
                    
                    // Post notification so SessionsViewController can reload
                    NotificationCenter.default.post(name: .sessionDidChange, object: nil)
                    
                    // Small delay to show success animation before dismissing
                    Task {
                        try? await Task.sleep(for: .seconds(0.75))
                        await MainActor.run {
                            self.showSuccessAndDismiss()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    // Stop loading button with failure
                    self.editSessionVC.saveButton.stopLoading(withSuccess: false)
                    self.showError(error)
                }
            }
        }
    }

    func editSessionViewController(_ controller: EditSessionViewController, didUpdateSession session: SessionItem) {
        // Not used in request completion flow
    }
}
