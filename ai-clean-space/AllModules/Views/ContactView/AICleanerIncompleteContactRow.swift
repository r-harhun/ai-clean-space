import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerIncompleteContactRow: View {
    let contact: CNContact
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                Text(fullName.isEmpty ? "No Name" : fullName)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                    Text(phoneNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let email = contact.emailAddresses.first?.value as? String {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if !contact.organizationName.isEmpty {
                    Text(contact.organizationName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
