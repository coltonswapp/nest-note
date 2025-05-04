//
//  NestCreationCoordinator.swift
//  nest-note
//
//  Created by Colton Swapp on 5/3/25.
//
import UIKit
import Combine

final class NestCreationCoordinator: NSObject, UINavigationControllerDelegate {
    
    private let navigationController: UINavigationController
    
    private let nestValidationSubject = CurrentValueSubject<Bool, Never>(false)
    
    var nestInfo: OnboardingCoordinator.UserOnboardingInfo.NestInfo?
    
    var nestValidation: AnyPublisher<Bool, Never> {
        nestValidationSubject.eraseToAnyPublisher()
    }
    
    override init() {
        self.navigationController = UINavigationController()
        super.init()

        navigationController.delegate = self
    }
    
    func start() -> UIViewController {
        let viewController = ATFCreateNestViewController()
        viewController.coordinator = self
        navigationController.setViewControllers([viewController], animated: false)
        return navigationController
    }
    
    func validateNest(name: String, address: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let isValid = !trimmedName.isEmpty && !trimmedAddress.isEmpty
        nestValidationSubject.send(isValid)
        
        if isValid {
            nestInfo = OnboardingCoordinator.UserOnboardingInfo.NestInfo(name: trimmedName, address: trimmedAddress)
        }
    }
    
    func createNest(completion: @escaping () -> Void) {
        guard let nestInfo,
            let name = nestInfo.name,
            let address = nestInfo.address else {
            return
        }
        
        Task {
            do {
                let createdNest = try await UserService.shared.setupNestForUser(userId: UserService.shared.currentUser!.id, nestName: name, nestAddress: address)
                try await UserService.shared.addNestAccessToUser(nestId: createdNest.id)
                
                await MainActor.run {
                    completion()
                }
            } catch {
                Logger.log(level: .error, message: "There was an error creating the nest (ATF): \(error)")
            }
        }
    }
}

class ATFCreateNestViewController: NNOnboardingViewController {
    private let topImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(imageView, for: .halfMoonBottom)
        imageView.alpha = 0.3
        return imageView
    }()
    
    private let nestNameField: NNTextField = {
        let field = NNTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Smith Nest"
        return field
    }()
    
    private let addressField: NNTextField = {
        let field = NNTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "321 Eagle Nest Ct, Birdsville CA"
        return field
    }()
    
    private let addressFootnoteLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Your address is only shared with sitters during sessions."
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .caption1)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private var loadingButton: NNLoadingButton?
    private var loadingButtonBottomConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Create your Nest",
            subtitle: "Give your nest a name & an address."
        )
        
        setupContent()
        addCTAButton(title: "Create Nest")
        setupActions()
        setupValidation()
        
        nestNameField.delegate = self
        addressField.delegate = self
        
        ctaButton?.isEnabled = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nestNameField.becomeFirstResponder()
    }
    
    override func addCTAButton(title: String, image: UIImage? = nil) {
        let button = NNLoadingButton(title: title, titleColor: .white, fillStyle: .fill(NNColors.primaryAlt))
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        
        buttonBottomConstraint = button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            button.heightAnchor.constraint(equalToConstant: 56),
            buttonBottomConstraint!
        ])
        
        self.ctaButton = button
    }
    
    func setupNavigationBarButtons() {
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeButtonTapped))
        let buttons = [closeButton]
        buttons.forEach { $0.tintColor = .label }
        navigationItem.rightBarButtonItems = buttons
    }
    
    private func setupValidation() {
        (coordinator as? NestCreationCoordinator)?.nestValidation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                self?.ctaButton?.isEnabled = isValid
            }
            .store(in: &cancellables)
        
        // Add text change handlers
        nestNameField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        addressField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    @objc private func textFieldDidChange() {
        (coordinator as? NestCreationCoordinator)?.validateNest(
            name: nestNameField.text ?? "",
            address: addressField.text ?? ""
        )
    }
    
    @objc func closeButtonTapped() {
        self.dismiss(animated: true)
    }

    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }
    
    @objc private func nextButtonTapped() {
        (ctaButton as? NNLoadingButton)?.startLoading()
        (coordinator as? NestCreationCoordinator)?.createNest {
            (self.ctaButton as? NNLoadingButton)?.stopLoading(withSuccess: true)
            self.finish()
        }
    }
    
    func finish() {
        
        guard let launchCoordinator = LaunchCoordinator.shared else {
            Logger.log(level: .error, message: "LaunchCoordinator shared instance not available")
            return
        }
        
        dismissAllViewControllers() {
            NotificationCenter.default.post(name: .modeDidChange, object: nil)

            Task {
                do {
                    try await Task.sleep(for: .seconds(2.0)) // TODO: Remove for prod
                    Logger.log(level: .info, message: "Reloading after nest creation (ATF)...")
                    try await launchCoordinator.switchMode(to: .nestOwner)
                } catch {
                    Logger.log(level: .error, message: "Failed to reload after nest creation (ATF): \(error.localizedDescription)")
                    (self.ctaButton as? NNLoadingButton)?.stopLoading(withSuccess: false)
                }
            }
        }
    }
    
    // MARK: - Setup
    override func setupContent() {
        view.addSubview(topImageView)
        topImageView.pinToBottom(of: view)
        
        view.addSubview(nestNameField)
        view.addSubview(addressField)
        view.addSubview(addressFootnoteLabel)
        
        NSLayoutConstraint.activate([
            nestNameField.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            nestNameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nestNameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            nestNameField.heightAnchor.constraint(equalToConstant: 56),
            
            addressField.topAnchor.constraint(equalTo: nestNameField.bottomAnchor, constant: 16),
            addressField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            addressField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            addressField.heightAnchor.constraint(equalToConstant: 56),
            
            addressFootnoteLabel.topAnchor.constraint(equalTo: addressField.bottomAnchor, constant: 8),
            addressFootnoteLabel.leadingAnchor.constraint(equalTo: addressField.leadingAnchor, constant: 8),
            addressFootnoteLabel.trailingAnchor.constraint(equalTo: addressField.trailingAnchor, constant: -8)
        ])
    }
}

extension ATFCreateNestViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nestNameField {
            addressField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
