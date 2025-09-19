import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct ContactCardView: UIViewControllerRepresentable {
    let contact: CNContact
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let contactViewController = CNContactViewController(for: contact)
        contactViewController.allowsEditing = true
        contactViewController.allowsActions = true
        
        // Add cancel and done buttons to dismiss the view
        contactViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: context.coordinator,
            action: #selector(context.coordinator.dismissView)
        )
        
        contactViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: context.coordinator,
            action: #selector(context.coordinator.dismissView)
        )
        
        let navigationController = UINavigationController(rootViewController: contactViewController)
        navigationController.navigationBar.prefersLargeTitles = false
        
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject {
        private let onDismiss: () -> Void
        
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }
        
        @objc func dismissView() {
            onDismiss()
        }
    }
}
