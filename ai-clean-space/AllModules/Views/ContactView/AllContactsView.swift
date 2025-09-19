import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AllContactsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedContacts: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showDeleteAlert = false
    @State private var selectedContactForNavigation: CNContact?
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let scalingFactor = geometry.size.height / 844
                
                ZStack {
                    CMColor.background
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: {
                                if isSelectionMode {
                                    isSelectionMode = false
                                    selectedContacts.removeAll()
                                } else {
                                    dismiss()
                                }
                            }) {
                                HStack(spacing: 6 * scalingFactor) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                                        .foregroundColor(CMColor.primary)
                                    
                                    Text(isSelectionMode ? "Cancel" : "Back")
                                        .font(.system(size: 17 * scalingFactor, weight: .regular))
                                        .foregroundColor(CMColor.primary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 2 * scalingFactor) {
                                Text(isSelectionMode ? "Select Contacts" : "Contacts")
                                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                                    .foregroundColor(CMColor.primaryText)
                                
                                if isSelectionMode && !selectedContacts.isEmpty {
                                    Text("\(selectedContacts.count) selected")
                                        .font(.system(size: 12 * scalingFactor, weight: .medium))
                                        .foregroundColor(CMColor.secondaryText)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                if isSelectionMode {
                                    if selectedContacts.isEmpty {
                                        selectedContacts = Set(filteredSystemContacts.map { $0.identifier })
                                    } else {
                                        selectedContacts.removeAll()
                                    }
                                } else {
                                    isSelectionMode = true
                                }
                            }) {
                                Text(isSelectionMode ?
                                     (selectedContacts.isEmpty ? "All" : "None") :
                                        "Select")
                                .font(.system(size: 17 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.primary)
                            }
                        }
                        .padding(.horizontal, 16 * scalingFactor)
                        .padding(.top, 8 * scalingFactor)
                        .padding(.bottom, 20 * scalingFactor)
                        
                        HStack {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(CMColor.secondaryText)
                                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                                
                                TextField("Search", text: $searchText)
                                    .font(.system(size: 16 * scalingFactor, weight: .regular))
                                    .foregroundColor(CMColor.primaryText)
                                
                                Spacer()
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(CMColor.secondaryText)
                                            .font(.system(size: 16 * scalingFactor))
                                    }
                                }
                            }
                            .padding(.horizontal, 16 * scalingFactor)
                            .padding(.vertical, 12 * scalingFactor)
                            .background(CMColor.backgroundSecondary)
                            .cornerRadius(12 * scalingFactor)
                        }
                        .padding(.horizontal, 16 * scalingFactor)
                        .padding(.bottom, 20 * scalingFactor)
                        
                        if isSelectionMode && !selectedContacts.isEmpty {
                            Button(action: {
                                showDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                                    
                                    Text("Delete \(selectedContacts.count) contact\(selectedContacts.count == 1 ? "" : "s")")
                                        .font(.system(size: 17 * scalingFactor, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48 * scalingFactor)
                                .background(CMColor.error)
                                .cornerRadius(12 * scalingFactor)
                            }
                            .padding(.horizontal, 16 * scalingFactor)
                            .padding(.bottom, 16 * scalingFactor)
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                                ForEach(sortedSectionKeys, id: \.self) { sectionKey in
                                    Section {
                                        if let contactsInSection = groupedContacts[sectionKey] {
                                            ForEach(Array(contactsInSection.enumerated()), id: \.element.identifier) { index, contact in
                                                if isSelectionMode {
                                                    SelectableSystemContactRowView(
                                                        contact: contact,
                                                        isSelected: selectedContacts.contains(contact.identifier),
                                                        isSelectionMode: isSelectionMode,
                                                        scalingFactor: scalingFactor,
                                                        onTap: {
                                                            toggleContactSelection(contact.identifier)
                                                        }
                                                    )
                                                } else {
                                                    NavigationLink(
                                                        destination: ContactCardPushView(contact: contact),
                                                        label: {
                                                            SystemContactRowView(contact: contact, scalingFactor: scalingFactor)
                                                        }
                                                    )
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                                
                                                if index < contactsInSection.count - 1 {
                                                    Divider()
                                                        .background(CMColor.border)
                                                        .padding(.horizontal, 16 * scalingFactor)
                                                }
                                            }
                                        }
                                    } header: {
                                        HStack {
                                            Text(sectionKey)
                                                .font(.system(size: 16 * scalingFactor, weight: .semibold))
                                                .foregroundColor(CMColor.secondaryText)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16 * scalingFactor)
                                        .padding(.vertical, 8 * scalingFactor)
                                        .background(CMColor.background)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            UINavigationBar.appearance().backIndicatorImage = UIImage(systemName: "chevron.left")
            UINavigationBar.appearance().backIndicatorTransitionMaskImage = UIImage(systemName: "chevron.left")
            UINavigationBar.appearance().layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        }
        .alert("Delete Contacts", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteSelectedContacts()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(selectedContacts.count) contact\(selectedContacts.count == 1 ? "" : "s") from your device?")
        }
    }
    
    private func toggleContactSelection(_ contactId: String) {
        if selectedContacts.contains(contactId) {
            selectedContacts.remove(contactId)
        } else {
            selectedContacts.insert(contactId)
        }
    }
    
    
    
    private func deleteSelectedContacts() {
        Task {
            let contactsToDelete = filteredSystemContacts.filter { selectedContacts.contains($0.identifier) }
            
            let success = await viewModel.deleteContacts(contactsToDelete)
            
            await MainActor.run {
                if success {
                    selectedContacts.removeAll()
                    isSelectionMode = false
                    Task {
                        await viewModel.loadSystemContacts()
                    }
                }
            }
        }
    }
    
    private var filteredSystemContacts: [CNContact] {
        if searchText.isEmpty {
            return viewModel.systemContacts.sorted {
                let name1 = "\($0.givenName) \($0.familyName)"
                let name2 = "\($1.givenName) \($1.familyName)"
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        } else {
            return viewModel.systemContacts.filter { contact in
                let fullName = "\(contact.givenName) \(contact.familyName)"
                let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }.joined()
                return fullName.localizedCaseInsensitiveContains(searchText) ||
                phoneNumbers.contains(searchText)
            }.sorted {
                let name1 = "\($0.givenName) \($0.familyName)"
                let name2 = "\($1.givenName) \($1.familyName)"
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
    }
    
    private var groupedContacts: [String: [CNContact]] {
        Dictionary(grouping: filteredSystemContacts) { contact in
            let firstName = contact.givenName.isEmpty ? contact.familyName : contact.givenName
            let firstLetter = String(firstName.prefix(1)).uppercased()
            return firstLetter.isEmpty ? "#" : firstLetter
        }
    }
    
    private var sortedSectionKeys: [String] {
        groupedContacts.keys.sorted { key1, key2 in
            if key1 == "#" { return false }
            if key2 == "#" { return true }
            return key1 < key2
        }
    }
}
