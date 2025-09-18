import SwiftUI

enum CategoryViewType: Identifiable, Hashable {
    case contacts
    case calendar
    case similarPhotos
    case duplicates
    case blurryPhotos
    case screenshots
    case videos
    
    var id: String {
        switch self {
        case .contacts: return "contacts"
        case .calendar: return "calendar"
        case .similarPhotos: return "similarPhotos"
        case .duplicates: return "duplicates"
        case .blurryPhotos: return "blurryPhotos"
        case .screenshots: return "screenshots"
        case .videos: return "videos"
        }
    }
}

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @Binding var isPaywallPresented: Bool
    
    @State private var presentedView: CategoryViewType?
    
    init(isPaywallPresented: Binding<Bool>) {
        self._isPaywallPresented = isPaywallPresented
        print("SCAN:TEST - MainViewModel init called")
    }
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    private var categories: [ScanItemType] {
        [.similar, .duplicates, .blurred, .screenshots, .videos, .contacts, .calendar]
    }
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI-Clean-Space")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        
                        if viewModel.progress < 1 {
                            Text("Scanning: \(Int(viewModel.progress * 100))%")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.gray)
                        } else {
                            Text(viewModel.subtitle)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                    
                    // Categories Section
                    VStack(spacing: 16) {
                        ForEach(categories, id: \.self) { type in
                            Button(action: {
                                handleTap(for: type)
                            }) {
                                CategoryRowView(
                                    type: type,
                                    viewModel: viewModel,
                                    generateEmptyStateImage: generateEmptyStateImage
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 100)
            }
            .onAppear {
                viewModel.onAppear()
                viewModel.scanContacts()
                viewModel.scanCalendar()
            }
            .fullScreenCover(item: $presentedView) { viewType in
                switch viewType {
                case .contacts:
                    ContactsView()
                case .calendar:
                    CalendarView()
                case .similarPhotos:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.similar)),
                            type: .similar
                        )
                    )
                case .duplicates:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.duplicates)),
                            type: .duplicates
                        )
                    )
                case .blurryPhotos:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.blurred)),
                            type: .blurred
                        )
                    )
                case .screenshots:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.screenshots)),
                            type: .screenshots
                        )
                    )
                case .videos:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .video),
                            type: .videos
                        )
                    )
                }
            }
        }
    }
    
    // Переместил этот метод сюда, чтобы он не лез в логику ViewModel
    private func generateEmptyStateImage(systemName: String, color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .regular, scale: .large)
        let image = UIImage(systemName: systemName, withConfiguration: config)
        return image?.withTintColor(color, renderingMode: .alwaysOriginal)
    }
    
    private func handleTap(for type: ScanItemType) {
        if !viewModel.hasActiveSubscription {
            isPaywallPresented = true
            return
        }
        
        switch type {
        case .contacts:
            if viewModel.contactsPermissionStatus == .authorized {
                presentedView = .contacts
            } else if viewModel.contactsPermissionStatus == .denied {
                viewModel.openAppSettings()
            }
        case .calendar:
            if viewModel.calendarPermissionStatus == .authorized {
                presentedView = .calendar
            } else if viewModel.calendarPermissionStatus == .denied {
                viewModel.openAppSettings()
            }
        case .similar:
            presentedView = .similarPhotos
        case .duplicates:
            presentedView = .duplicates
        case .blurred:
            presentedView = .blurryPhotos
        case .screenshots:
            presentedView = .screenshots
        case .videos:
            presentedView = .videos
        }
    }
}

// MARK: - Category Row View
struct CategoryRowView: View {
    let type: ScanItemType
    @ObservedObject var viewModel: MainViewModel
    // Добавил замыкание для передачи метода
    let generateEmptyStateImage: (String, UIColor) -> UIImage?
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if let image = getPreviewImage() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray5))
                        .frame(width: 60, height: 60)
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(type.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                
                Text(getItemCountText())
                    .font(.callout)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // Теперь этот метод использует переданное замыкание
    private func getPreviewImage() -> UIImage? {
        switch type {
        case .contacts:
            return viewModel.contactsPermissionStatus == .authorized ?
            generateEmptyStateImage("person.circle.fill", .systemBlue) :
            generateEmptyStateImage("person.fill.questionmark", .systemOrange)
        case .calendar:
            return viewModel.calendarPermissionStatus == .authorized ?
            generateEmptyStateImage("calendar.badge.clock", .systemGreen) :
            generateEmptyStateImage("calendar.badge.exclamationmark", .systemOrange)
        case .similar:
            return viewModel.previews.similar
        case .duplicates:
            return viewModel.previews.duplicates
        case .blurred:
            return viewModel.previews.blurred
        case .screenshots:
            return viewModel.previews.screenshots
        case .videos:
            return viewModel.previews.videos
        }
    }
    
    private func getItemCountText() -> String {
        switch type {
        case .contacts:
            switch viewModel.contactsPermissionStatus {
            case .authorized:
                return viewModel.isContactsLoading ? "Loading contacts..." :
                    (viewModel.contactsCount == 0 ? "No contacts" : "\(viewModel.contactsCount) contacts")
            case .notDetermined: return "Requesting permission..."
            case .denied: return "Tap to open Settings"
            case .loading: return "Checking access..."
            }
        case .calendar:
            switch viewModel.calendarPermissionStatus {
            case .authorized:
                return viewModel.isCalendarLoading ? "Loading events..." :
                    (viewModel.calendarEventsCount == 0 ? "No events" : "\(viewModel.calendarEventsCount) events")
            case .notDetermined: return "Requesting permission..."
            case .denied: return "Tap to open Settings"
            case .loading: return "Checking access..."
            }
        case .similar:
            return "\(viewModel.counts.similar) items • \(viewModel.megabytes.similar.formatAsFileSize())"
        case .duplicates:
            return "\(viewModel.counts.duplicates) items • \(viewModel.megabytes.duplicates.formatAsFileSize())"
        case .blurred:
            return "\(viewModel.counts.blurred) items • \(viewModel.megabytes.blurred.formatAsFileSize())"
        case .screenshots:
            return "\(viewModel.counts.screenshots) items • \(viewModel.megabytes.screenshots.formatAsFileSize())"
        case .videos:
            return "\(viewModel.counts.videos) items • \(viewModel.megabytes.videos.formatAsFileSize())"
        }
    }
}
