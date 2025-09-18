import SwiftUI
import LocalAuthentication
import UIKit

struct PINView: View {
    @State private var enteredCode: String = ""
    @State private var pinSetupState: PinSetupState = .entry
    @State private var storedPin: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var biometricType: LABiometryType = .none
    @State private var isBiometricAvailable: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - New State for Change Passcode Flow
    @State private var changePasscodeState: ChangePasscodeFlowState = .verifyingOldPin
    
    let requiredLength: Int = 4
    let onTabBarVisibilityChange: (Bool) -> Void
    let onCodeEntered: (String) -> Void
    let onBackButtonTapped: () -> Void
    let shouldAutoDismiss: Bool
    
    // MARK: - New Property
    let isChangingPasscode: Bool
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    enum PinSetupState {
        case setup
        case entry
        case confirm
    }
    
    // MARK: - New Enum
    enum ChangePasscodeFlowState {
        case verifyingOldPin
        case settingNewPin
        case confirmingNewPin
    }
    
    init(
        onTabBarVisibilityChange: @escaping (Bool) -> Void = { _ in },
        onCodeEntered: @escaping (String) -> Void = { _ in },
        onBackButtonTapped: @escaping () -> Void = { },
        shouldAutoDismiss: Bool = true,
        isChangingPasscode: Bool = false
    ) {
        self.onTabBarVisibilityChange = onTabBarVisibilityChange
        self.onCodeEntered = onCodeEntered
        self.onBackButtonTapped = onBackButtonTapped
        self.shouldAutoDismiss = shouldAutoDismiss
        self.isChangingPasscode = isChangingPasscode
    }
    
    var body: some View {
        ZStack {
            CMColor.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Redesigned Header with Back Button
                HStack {
                    Button(action: {
                        // Логика кнопки "Назад"
                        onBackButtonTapped()
                    }) {
                        HStack(spacing: 6 * scalingFactor) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(CMColor.primary)
                            
                            Text("Back")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(CMColor.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Text(titleText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Spacer()
                    
                    // Invisible button for alignment
                    Button(action: {}) {
                        HStack(spacing: 6 * scalingFactor) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17, weight: .regular))
                        }
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 16 * scalingFactor)
                .padding(.top, 50 * scalingFactor)
                
                // MARK: - Description Text
                Text(descriptionText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30 * scalingFactor)
                    .padding(.top, 10 * scalingFactor)
                
                Spacer()
                
                // MARK: - Redesigned PIN Code Section
                VStack(spacing: 32 * scalingFactor) {
                    HStack(spacing: 20 * scalingFactor) {
                        ForEach(0..<requiredLength, id: \.self) { index in
                            Circle()
                                .stroke(lineWidth: 2)
                                .fill(dotColor(for: index).opacity(0.5))
                                .frame(width: 16 * scalingFactor, height: 16 * scalingFactor)
                                .overlay(
                                    Circle()
                                        .fill(dotColor(for: index))
                                        .frame(width: 16 * scalingFactor, height: 16 * scalingFactor)
                                        .scaleEffect(index < enteredCode.count ? 1.0 : 0.0)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: enteredCode.count)
                                )
                                .animation(.easeInOut(duration: 0.2), value: showError)
                        }
                    }
                    
                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(CMColor.error)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16 * scalingFactor)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxHeight: 200)
                
                Spacer()
                
                // MARK: - Redesigned Keypad Section
                VStack(spacing: 24 * scalingFactor) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 36 * scalingFactor) {
                            ForEach(1...3, id: \.self) { column in
                                let number = row * 3 + column
                                KeyboardButton(
                                    text: "\(number)",
                                    action: { addDigit("\(number)") }
                                )
                            }
                        }
                    }
                    
                    HStack(spacing: 36 * scalingFactor) {
                        if shouldShowBiometricButton {
                            Button(action: {
                                authenticateWithBiometrics()
                            }) {
                                Image(systemName: biometricIconName)
                                    .font(.system(size: 24 * scalingFactor, weight: .regular))
                                    .foregroundColor(CMColor.primaryText)
                                    .frame(width: 72 * scalingFactor, height: 72 * scalingFactor)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 72 * scalingFactor, height: 72 * scalingFactor)
                        }
                        
                        KeyboardButton(
                            text: "0",
                            action: { addDigit("0") }
                        )
                        
                        Button(action: deleteDigit) {
                            Image(systemName: "delete.backward.fill")
                                .font(.system(size: 24 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.primaryText)
                                .frame(width: 72 * scalingFactor, height: 72 * scalingFactor)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(enteredCode.isEmpty ? 0.3 : 1.0)
                        .disabled(enteredCode.isEmpty)
                    }
                }
                .padding(.bottom, 64 * scalingFactor)
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            checkPinStatus()
            onTabBarVisibilityChange(false)
        }
        .onDisappear {
            onTabBarVisibilityChange(true)
        }
    }
    
    // MARK: - Helper Properties
    private var titleText: String {
        if isChangingPasscode {
            switch changePasscodeState {
            case .verifyingOldPin:
                return "Change Password"
            case .settingNewPin:
                return "Enter New PIN"
            case .confirmingNewPin:
                return "Confirm New PIN"
            }
        } else {
            switch pinSetupState {
            case .setup:
                return "Create Password"
            case .entry:
                return "Safe Storage"
            case .confirm:
                return "Confirm PIN"
            }
        }
    }
    
    private var descriptionText: String {
        if isChangingPasscode {
            switch changePasscodeState {
            case .verifyingOldPin:
                return "Enter your current PIN to continue"
            case .settingNewPin:
                return "Create a new 4-digit PIN"
            case .confirmingNewPin:
                return "Confirm your new PIN"
            }
        } else {
            switch pinSetupState {
            case .setup:
                return "Create a 4-digit PIN to secure your safe storage"
            case .entry:
                return "Enter your PIN to unlock"
            case .confirm:
                return "Confirm your 4-digit PIN"
            }
        }
    }
    
    private var shouldShowBiometricButton: Bool {
        return isBiometricAvailable &&
               pinSetupState == .entry &&
               !isChangingPasscode
    }
    
    private var biometricIconName: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "faceid"
        }
    }
    
    // MARK: - Helper Methods
    private func dotColor(for index: Int) -> Color {
        if showError {
            return CMColor.error
        } else if index < enteredCode.count {
            return CMColor.activeButton
        } else {
            return CMColor.secondaryText.opacity(0.3)
        }
    }
    
    private func clearError() {
        if showError {
            withAnimation(.easeInOut(duration: 0.3)) {
                showError = false
                errorMessage = ""
            }
        }
    }
    
    private func showErrorState(message: String) {
        errorMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showError = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            clearError()
        }
    }
    
    private func addDigit(_ digit: String) {
        guard enteredCode.count < requiredLength else { return }
        
        clearError()
        enteredCode += digit
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if enteredCode.count == requiredLength {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                handleCompleteCode()
            }
        }
    }
    
    private func handleCompleteCode() {
        if isChangingPasscode {
            handlePasscodeChangeFlow()
        } else {
            handlePinSetupFlow()
        }
    }
    
    private func handlePinSetupFlow() {
        switch pinSetupState {
        case .setup:
            storedPin = enteredCode
            pinSetupState = .confirm
            enteredCode = ""
            
        case .confirm:
            if enteredCode == storedPin {
                UserDefaults.standard.set(enteredCode, forKey: "safe_storage_pin")
                onCodeEntered(enteredCode)
                
                if shouldAutoDismiss {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } else {
                showErrorState(message: "PINs don't match. Please try again.")
                enteredCode = ""
                storedPin = ""
                pinSetupState = .setup
                
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
        case .entry:
            let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin") ?? ""
            if enteredCode == savedPin {
                onCodeEntered(enteredCode)
                
                if shouldAutoDismiss {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } else {
                showErrorState(message: "Incorrect PIN. Please try again.")
                enteredCode = ""
                
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
    
    private func handlePasscodeChangeFlow() {
        switch changePasscodeState {
        case .verifyingOldPin:
            let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin") ?? ""
            if enteredCode == savedPin {
                enteredCode = ""
                withAnimation {
                    changePasscodeState = .settingNewPin
                }
            } else {
                showErrorState(message: "Incorrect PIN. Please try again.")
                enteredCode = ""
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
        case .settingNewPin:
            storedPin = enteredCode
            enteredCode = ""
            withAnimation {
                changePasscodeState = .confirmingNewPin
            }
            
        case .confirmingNewPin:
            if enteredCode == storedPin {
                UserDefaults.standard.set(enteredCode, forKey: "safe_storage_pin")
                onCodeEntered(enteredCode)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            } else {
                showErrorState(message: "PINs don't match. Please try again.")
                enteredCode = ""
                storedPin = ""
                withAnimation {
                    changePasscodeState = .settingNewPin
                }
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
    
    private func checkPinStatus() {
        if !isChangingPasscode {
            let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin")
            if savedPin == nil || savedPin?.isEmpty == true {
                pinSetupState = .setup
            } else {
                pinSetupState = .entry
            }
        }
        
        checkBiometricAvailability()
    }
    
    // MARK: - Biometric Authentication Methods
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricAvailable = true
            biometricType = context.biometryType
        } else {
            isBiometricAvailable = false
            biometricType = .none
        }
    }
    
    private func authenticateWithBiometrics() {
        guard isBiometricAvailable else { return }
        
        let context = LAContext()
        let reason = "Use biometrics to access your secure storage."
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin") ?? ""
                    self.onCodeEntered(savedPin)
                    
                    if self.shouldAutoDismiss {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.dismiss()
                        }
                    }
                } else if let error = error {
                    self.handleBiometricError(error as NSError)
                }
            }
        }
    }
    
    private func handleBiometricError(_ error: NSError) {
        let message: String
        
        switch error.code {
        case LAError.biometryNotAvailable.rawValue:
            message = "Biometric authentication is not available."
        case LAError.biometryNotEnrolled.rawValue:
            message = "Biometric data is not configured."
        case LAError.biometryLockout.rawValue:
            message = "Biometrics is locked. Try again later."
        case LAError.userCancel.rawValue:
            return
        case LAError.userFallback.rawValue:
            return
        default:
            message = "Biometric authentication error."
        }
        
        showErrorState(message: message)
    }
    
    private func deleteDigit() {
        guard !enteredCode.isEmpty else { return }
        
        clearError()
        enteredCode.removeLast()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}
