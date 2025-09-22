import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isPaywallPresented: Bool
    
    @StateObject private var viewModel = SettingsViewModel()
    
    // MARK: - Navigation state
    @State private var showBackupView: Bool = false
    @State private var showChangePasscodeView: Bool = false

    private var contentScalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24 * contentScalingFactor) {
                settingsPageHeader
                
                secretVaultSection
                
                aboutAppSection
            }
            .padding(.horizontal, 16 * contentScalingFactor)
            .padding(.bottom, 100 * contentScalingFactor)
        }
        .fullScreenCover(isPresented: $showBackupView) {
            BackupView()
        }
        .fullScreenCover(isPresented: $showChangePasscodeView) {
            PINView(
                onTabBarVisibilityChange: { _ in },
                onCodeEntered: { code in
                    print("New passcode saved: \(code)")
                },
                onBackButtonTapped: {
                    showChangePasscodeView = false
                },
                shouldAutoDismiss: true,
                isChangingPasscode: true
            )
        }
    }
    
    // MARK: - Settings Header Section
    private var settingsPageHeader: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
            }
            
            Spacer()
            
            Text("Settings")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
        }
        .padding(.top, 20 * contentScalingFactor)
    }

    // MARK: - Security and Privacy Section
    private var securityAndPrivacySection: some View {
        VStack(alignment: .leading, spacing: 10 * contentScalingFactor) {
            Text("Security & Privacy")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                
            VStack(spacing: 0) {
                SettingsRow(title: "Enable passcode in app", isToggle: true, isOn: $viewModel.isPasscodeEnabledInApp, isFirst: true)
                
                Divider().background(CMColor.backgroundSecondary).padding(.horizontal, 16 * contentScalingFactor)
                
                SettingsRow(title: "Change passcode", icon: "chevron.right", isOn: .constant(false), isNavigation: true, action: {
                    showChangePasscodeView = true
                })
                .disabled(!viewModel.isPasscodeEnabledInApp)
                .opacity(viewModel.isPasscodeEnabledInApp ? 1.0 : 0.5)
                
                Divider().background(CMColor.backgroundSecondary).padding(.horizontal, 16 * contentScalingFactor)
                
                SettingsRow(title: "Face ID in app", isToggle: true, isOn: $viewModel.isFaceIDInAppEnabled, isLast: true)
                .disabled(!viewModel.isPasscodeEnabledInApp)
                .opacity(viewModel.isPasscodeEnabledInApp ? 1.0 : 0.5)
            }
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16 * contentScalingFactor))
        }
    }
    
    // MARK: - Private Vault Section
    private var secretVaultSection: some View {
        VStack(alignment: .leading, spacing: 10 * contentScalingFactor) {
            Text("Private Vault")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                
            VStack(spacing: 0) {
                SettingsRow(title: "Change passcode", icon: "chevron.right", isOn: .constant(false), isNavigation: true, isFirst: true, isLast: true, action: {
                    showChangePasscodeView = true
                })
            }
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16 * contentScalingFactor))
        }
    }
    
    // MARK: - About App Section
    private var aboutAppSection: some View {
        VStack(alignment: .leading, spacing: 10 * contentScalingFactor) {
            Text("About")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                
            VStack(spacing: 0) {
                SettingsRow(title: "License agreement", icon: "chevron.right", isOn: .constant(false), isNavigation: true, isFirst: true, action: {
                    viewModel.licenseAgreementTapped()
                })
                
                Divider().background(CMColor.backgroundSecondary).padding(.horizontal, 16 * contentScalingFactor)
                
                SettingsRow(title: "Privacy policy", icon: "chevron.right", isOn: .constant(false), isNavigation: true, action: {
                    viewModel.privacyPolicyTapped()
                })
                
                Divider().background(CMColor.backgroundSecondary).padding(.horizontal, 16 * contentScalingFactor)
                
                SettingsRow(title: "Send feedback", icon: "chevron.right", isOn: .constant(false), isNavigation: true, isLast: true, action: {
                    viewModel.sendFeedbackTapped()
                })
            }
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16 * contentScalingFactor))
        }
    }
}
