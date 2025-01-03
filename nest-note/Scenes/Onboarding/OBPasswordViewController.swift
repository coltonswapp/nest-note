//final class OBPasswordViewController: NNOnboardingViewController {
//    private var cancellables = Set<AnyCancellable>()
//    
//    private func setupValidation() {
//        coordinator?.passwordValidation
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] validation in
//                self?.ctaButton?.isEnabled = validation.isValid
//                self?.updateRequirement(self?.lengthRequirement, isValid: validation.hasMinLength)
//                self?.updateRequirement(self?.capitalRequirement, isValid: validation.hasCapital)
//                self?.updateRequirement(self?.numberRequirement, isValid: validation.hasNumber)
//                self?.updateRequirement(self?.symbolRequirement, isValid: validation.hasSymbol)
//                self?.updateRequirement(self?.passwordMatchRequirement, isValid: validation.passwordsMatch)
//            }
//            .store(in: &cancellables)
//    }
//    
//    @objc private func textFieldDidChange() {
//        coordinator?.validatePassword(
//            password: passwordTextField.text ?? "",
//            confirmPassword: confirmPasswordTextField.text ?? ""
//        )
//    }
//} 
