import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct ContactRowView: View {
    let contact: ContactData
    let scalingFactor: CGFloat
    
    var body: some View {
        HStack(spacing: 16 * scalingFactor) {
            ZStack {
                Circle()
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 50 * scalingFactor, height: 50 * scalingFactor)
                
                Text(contact.initials)
                    .font(.system(size: 18 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primary)
            }
            
            VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                Text(contact.fullName)
                    .font(.system(size: 17 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(contact.formattedPhoneNumber)
                    .font(.system(size: 15 * scalingFactor, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 16 * scalingFactor)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}
