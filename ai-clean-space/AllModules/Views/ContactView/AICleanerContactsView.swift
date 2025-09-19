import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerContactsView: View {
    @StateObject private var viewModel = AICleanerContactsViewModel()
    @StateObject private var permissionManager = ContactsPermissionManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAllContacts = false
    @State private var showDuplicates = false
    @State private var showIncomplete = false
    
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            ZStack {
                CMColor.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView(scalingFactor: scalingFactor)
                    
                    if !permissionManager.canAccessContacts {
                        permissionRequestView(scalingFactor: scalingFactor)
                    } else if viewModel.isLoading {
                        loadingView(scalingFactor: scalingFactor)
                    } else {
                        ScrollView {
                            VStack(spacing: 16 * scalingFactor) {
                                ForEach(ContactCategory.allCases, id: \.self) { category in
                                    contactCategoryButton(
                                        category: category,
                                        scalingFactor: scalingFactor
                                    )
                                }
                            }
                            .padding(.horizontal, 16 * scalingFactor)
                            .padding(.top, 24 * scalingFactor)
                            .padding(.bottom, 32 * scalingFactor)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showAllContacts) {
            AICleanerAllContactsView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showDuplicates) {
            AICleanerDuplicateContactsView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showIncomplete) {
            AICleanerIncompleteContactsView(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .task {
            await performContactsScan()
        }
        .onChange(of: permissionManager.authorizationStatus) { newStatus in
            if newStatus == .authorized {
                Task {
                    await performContactsScan()
                }
            }
        }
        .onAppear {
            Task {
                await performContactsScan()
            }
        }
    }
    
    // MARK: - Header View
    private func headerView(scalingFactor: CGFloat) -> some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                    
                    Text("Back")
                        .font(.system(size: 17 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.primary)
                }
            }
            .frame(width: 80 * scalingFactor, alignment: .leading)
            
            Spacer()
            
            VStack(spacing: 4 * scalingFactor) {
                Text("Contacts")
                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                if viewModel.isLoading {
                    HStack(spacing: 4 * scalingFactor) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: CMColor.primary))
                            .scaleEffect(0.6)
                        
                        Text("Scanning...")
                            .font(.system(size: 12 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                    }
                } else if !viewModel.duplicateGroups.isEmpty {
                    let totalDuplicates = viewModel.duplicateGroups.flatMap { $0 }.count
                    Text("\(viewModel.duplicateGroups.count) groups • \(totalDuplicates) duplicates")
                        .font(.system(size: 12 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.error)
                } else if !viewModel.systemContacts.isEmpty {
                    Text("\(viewModel.systemContacts.count) contacts • No duplicates")
                        .font(.system(size: 12 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.success)
                }
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await performContactsScan()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
                    .rotationEffect(viewModel.isLoading ? Angle(degrees: 360) : Angle(degrees: 0))
                    .animation(viewModel.isLoading ?
                               Animation.linear(duration: 1).repeatForever(autoreverses: false) :
                            .default, value: viewModel.isLoading)
            }
            .disabled(viewModel.isLoading)
            .frame(width: 80 * scalingFactor, alignment: .trailing)
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.top, 8 * scalingFactor)
        .padding(.bottom, 20 * scalingFactor)
    }
    
    private func contactCategoryButton(category: ContactCategory, scalingFactor: CGFloat) -> some View {
        Button(action: {
            switch category {
            case .allContacts:
                showAllContacts = true
            case .duplicates:
                showDuplicates = true
            case .incomplete:
                showIncomplete = true
            }
        }) {
            HStack(spacing: 16 * scalingFactor) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12 * scalingFactor)
                        .fill(CMColor.primary.opacity(0.1))
                        .frame(width: 56 * scalingFactor, height: 56 * scalingFactor)
                    
                    Image(systemName: category.systemImage)
                        .font(.system(size: 24 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                }
                
                VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                    Text(category.rawValue)
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text(getSubtitleForCategory(category))
                        .font(.system(size: 15 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4 * scalingFactor) {
                    Text(getCountForCategory(category))
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.secondaryText)
                }
            }
            .padding(.horizontal, 20 * scalingFactor)
            .padding(.vertical, 16 * scalingFactor)
            .background(
                RoundedRectangle(cornerRadius: 16 * scalingFactor)
                    .fill(CMColor.surface)
                    .shadow(color: .black.opacity(0.05), radius: 4 * scalingFactor, x: 0, y: 2 * scalingFactor)
            )
        }
    }
    
    private func getSubtitleForCategory(_ category: ContactCategory) -> String {
        switch category {
        case .allContacts:
            return "View and manage all contacts"
        case .duplicates:
            return "Find and merge duplicate contacts"
        case .incomplete:
            return "Contacts missing information"
        }
    }
    
    private func getCountForCategory(_ category: ContactCategory) -> String {
        switch category {
        case .allContacts:
            return "\(viewModel.systemContacts.count)"
        case .duplicates:
            let duplicateCount = viewModel.duplicateGroups.flatMap { $0 }.count
            return "\(duplicateCount)"
        case .incomplete:
            let incompleteCount = viewModel.systemContacts.filter { isIncompleteContact($0) }.count
            return "\(incompleteCount)"
        }
    }
    
    private func isIncompleteContact(_ contact: CNContact) -> Bool {
        let hasName = !contact.givenName.isEmpty || !contact.familyName.isEmpty
        let hasPhone = !contact.phoneNumbers.isEmpty
        
        return !hasName || !hasPhone
    }
    
    
    
    private func permissionRequestView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 24 * scalingFactor) {
            Spacer()
            
            VStack(spacing: 16 * scalingFactor) {
                Image(systemName: "person.2.circle")
                    .font(.system(size: 64 * scalingFactor))
                    .foregroundColor(CMColor.primary)
                
                VStack(spacing: 8 * scalingFactor) {
                    Text("Access to Contacts")
                        .font(.system(size: 24 * scalingFactor, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text("To find and merge duplicate contacts, we need access to your contacts")
                        .font(.system(size: 16 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32 * scalingFactor)
                }
                
                Button(action: {
                    requestContactsPermission()
                }) {
                    Text(permissionManager.shouldRedirectToSettings ? "Open Settings" : "Allow Access")
                        .font(.system(size: 17 * scalingFactor, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50 * scalingFactor)
                        .background(CMColor.primary)
                        .cornerRadius(12 * scalingFactor)
                }
                .padding(.horizontal, 32 * scalingFactor)
                .padding(.top, 16 * scalingFactor)
            }
            
            Spacer()
        }
    }
    
    private func loadingView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 16 * scalingFactor)
            
            Text("Loading contacts...")
                .font(.system(size: 16 * scalingFactor, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
            
            Spacer()
        }
    }
    
    private func performContactsScan() async {
        permissionManager.checkAuthorizationStatus()
        
        guard permissionManager.canAccessContacts else {
            return
        }
        
        await viewModel.loadSystemContacts()
    }
    
    private func requestContactsPermission() {
        if permissionManager.shouldRedirectToSettings {
            permissionManager.openAppSettings()
        } else {
            Task {
                await permissionManager.requestAccess()
            }
        }
    }
}
