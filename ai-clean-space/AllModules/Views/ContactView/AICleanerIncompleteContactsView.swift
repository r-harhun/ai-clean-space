import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerIncompleteContactsView: View {
    @ObservedObject var viewModel: AICleanerContactsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(CMColor.primary)
                    
                    Spacer()
                    
                    Text("Incomplete")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("") { }
                        .disabled(true)
                        .opacity(0)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Name, number, company or email", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 16)
                
                if incompleteContacts.isEmpty {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        
                        VStack(spacing: 8) {
                            Text("All Contacts Complete")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("All your contacts have complete information. Great job keeping your contacts organized!")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                    
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredIncompleteContacts.enumerated()), id: \.element.identifier) { index, contact in
                                NavigationLink(destination: AICleanerContactCardPushView(contact: contact)) {
                                    AICleanerIncompleteContactRow(contact: contact)
                                        .background(Color(.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if index < filteredIncompleteContacts.count - 1 {
                                    Divider()
                                        .background(Color(.separator))
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
        }
        .navigationBarHidden(true)
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var incompleteContacts: [CNContact] {
        return viewModel.systemContacts.filter { contact in
            let hasName = !contact.givenName.isEmpty || !contact.familyName.isEmpty
            let hasPhone = !contact.phoneNumbers.isEmpty
            
            return !hasName || !hasPhone
        }
    }
    
    private var filteredIncompleteContacts: [CNContact] {
        let contacts = searchText.isEmpty ? incompleteContacts : incompleteContacts.filter { contact in
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }.joined(separator: " ")
            let emails = contact.emailAddresses.map { $0.value as String }.joined(separator: " ")
            let company = contact.organizationName
            
            let searchQuery = searchText.lowercased()
            
            return fullName.lowercased().contains(searchQuery) ||
            phoneNumbers.lowercased().contains(searchQuery) ||
            emails.lowercased().contains(searchQuery) ||
            company.lowercased().contains(searchQuery)
        }
        
        return contacts.sorted {
            let name1 = "\($0.givenName) \($0.familyName)".trimmingCharacters(in: .whitespaces)
            let name2 = "\($1.givenName) \($1.familyName)".trimmingCharacters(in: .whitespaces)
            
            if name1.isEmpty && !name2.isEmpty { return false }
            if !name1.isEmpty && name2.isEmpty { return true }
            if name1.isEmpty && name2.isEmpty { return false }
            
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
}
