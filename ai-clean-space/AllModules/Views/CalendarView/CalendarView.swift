import SwiftUI
import EventKit

struct CalendarView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var calendarService = CalendarService()

    @State private var selectedTab: CalendarFilter = .allEvents
    @State private var searchText: String = ""
    @State private var selectedEventIds = Set<String>()
    @State private var showingPermissionAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCannotDeleteAlert = false
    @State private var cannotDeleteMessage = ""
    @State private var cannotDeleteEvents: [(SystemCalendarEvent, EventDeletionError)] = []
    @State private var showingInstructions = false

    @State private var startDate: Date = {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()
    @State private var endDate = Date()

    @State private var showingStartDatePicker = false
    @State private var showingEndDatePicker = false

    var filteredEvents: [CalendarEvent] {
        let calendarEvents = calendarService.events.map { CalendarEvent(from: $0) }
        
        let start = min(startDate, endDate)
        let end = max(startDate, endDate)
        
        let filteredByDate = calendarEvents.filter { event in
            return event.date >= start && event.date <= end
        }
        
        let filteredBySearch = filteredByDate.filter { event in
            return searchText.isEmpty || event.title.localizedCaseInsensitiveContains(searchText) || event.source.localizedCaseInsensitiveContains(searchText)
        }
        
        switch selectedTab {
        case .allEvents:
            let result = filteredBySearch.filter { !$0.isWhiteListed }
            return result
        case .whiteList:
            let result = filteredBySearch.filter { $0.isWhiteListed }
            return result
        }
    }

    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: startDate)
    }

    var formattedEndDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: endDate)
    }

    enum CalendarFilter {
        case allEvents
        case whiteList
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                let hasAccess = if #available(iOS 17.0, *) {
                    calendarService.authorizationStatus == .fullAccess
                } else {
                    calendarService.authorizationStatus == .authorized
                }
                
                if calendarService.authorizationStatus == .denied {
                    permissionDeniedView()
                } else if calendarService.authorizationStatus == .notDetermined {
                    requestPermissionView()
                } else if !hasAccess {
                    permissionDeniedView()
                } else {
                    filterButtonsView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    
                    searchBarView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    
                    dateNavigationView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    
                    if calendarService.isLoading {
                        loadingView()
                    } else if filteredEvents.isEmpty && !searchText.isEmpty {
                        emptyStateView()
                    } else if filteredEvents.isEmpty {
                        noEventsView()
                    } else {
                        eventsListView()
                    }
                }
                
                Spacer()
                
                if !selectedEventIds.isEmpty {
                    actionButtonsView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(CMColor.background.ignoresSafeArea())
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingStartDatePicker) {
            SystemDatePickerView(selectedDate: $startDate)
                .onDisappear {
                    Task {
                        await calendarService.loadEvents(from: startDate, to: endDate)
                    }
                }
        }
        .sheet(isPresented: $showingEndDatePicker) {
            SystemDatePickerView(selectedDate: $endDate)
                .onDisappear {
                    Task {
                        await calendarService.loadEvents(from: startDate, to: endDate)
                    }
                }
        }
        .onAppear {
            if calendarService.authorizationStatus == .notDetermined {
                Task {
                    await calendarService.requestCalendarAccess()
                }
            } else {
                Task {
                    await calendarService.loadEvents(from: startDate, to: endDate)
                }
            }
        }
        .alert("Calendar Access Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable calendar access in Settings to view your events.")
        }
        .alert("Delete Events", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedEvents()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(selectedEventIds.count) selected event(s) from your calendar? This action cannot be undone.")
        }
        .overlay {
            if showingCannotDeleteAlert {
                CannotDeleteEventView(
                    eventTitle: cannotDeleteEvents.first?.0.calendar ?? "Unknown Calendar",
                    message: cannotDeleteMessage,
                    onGuide: {
                        showingCannotDeleteAlert = false
                        showingInstructions = true
                    },
                    onCancel: {
                        showingCannotDeleteAlert = false
                    }
                )
                .animation(.easeInOut(duration: 0.3), value: showingCannotDeleteAlert)
            }
        }
        .sheet(isPresented: $showingInstructions) {
            CalendarInstructionsView()
        }
    }

    // MARK: - Subviews
    
    private func headerView() -> some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            Text("Calendar")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    if selectedEventIds.count == filteredEvents.count && !filteredEvents.isEmpty {
                        selectedEventIds.removeAll()
                    } else {
                        selectedEventIds = Set(filteredEvents.map { $0.eventIdentifier })
                    }
                }
            }) {
                Text(selectedEventIds.count == filteredEvents.count && !filteredEvents.isEmpty ? "Deselect All" : "Select All")
                    .foregroundColor(CMColor.primary)
            }
        }
    }
    
    private func filterButtonsView() -> some View {
        HStack(spacing: 0) {
            ForEach([CalendarFilter.allEvents, .whiteList], id: \.self) { filter in
                Button(action: {
                    withAnimation {
                        selectedTab = filter
                        selectedEventIds.removeAll()
                    }
                }) {
                    Text(filterName(for: filter))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(selectedTab == filter ? .white : CMColor.secondaryText)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            selectedTab == filter ? CMColor.primary : .clear
                        )
                        .cornerRadius(12)
                }
            }
        }
        .padding(4)
        .background(CMColor.backgroundSecondary)
        .cornerRadius(16)
    }
    
    private func searchBarView() -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(CMColor.secondaryText)
            TextField("Search", text: $searchText)
                .foregroundColor(CMColor.primaryText)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(CMColor.secondaryText)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CMColor.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private func dateNavigationView() -> some View {
        HStack {
            Button(action: {
                showingStartDatePicker = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text(formattedStartDate)
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            Button(action: {
                showingEndDatePicker = true
            }) {
                HStack(spacing: 8) {
                    Text(formattedEndDate)
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(CMColor.primary)
            }
        }
    }
    
    private func eventsListView() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredEvents) { event in
                    EventRowView(
                        event: event,
                        isSelected: selectedEventIds.contains(event.eventIdentifier),
                        onSelect: {
                            if selectedEventIds.contains(event.eventIdentifier) {
                                selectedEventIds.remove(event.eventIdentifier)
                            } else {
                                selectedEventIds.insert(event.eventIdentifier)
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    
                    Divider()
                        .background(CMColor.border)
                        .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private func emptyStateView() -> some View {
        VStack(spacing: 8) {
            Text("The search has not given any results")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                .multilineTextAlignment(.center)
            
            Text("Try changing your search parameters or choosing a different range")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func actionButtonsView() -> some View {
        HStack(spacing: 12) {
            if selectedTab == .whiteList {
                Button(action: {
                    removeFromWhiteList()
                }) {
                    Text("Remove from white list")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CMColor.secondary)
                        .cornerRadius(12)
                }
            } else {
                Button(action: {
                    addToWhiteList()
                }) {
                    Text("To white list")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CMColor.secondary)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Text("Delete")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CMColor.error)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Permission Views
    
    private func requestPermissionView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(CMColor.primary)
            
            Text("Calendar Access Required")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            Text("To clean up your calendar events, we need access to your calendar. Your data stays private and secure.")
                .font(.system(size: 16))
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Task {
                    await calendarService.requestCalendarAccess()
                }
            }) {
                Text("Grant Access")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CMColor.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func permissionDeniedView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(CMColor.error)
            
            Text("Calendar Access Denied")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            Text("Please enable calendar access in Settings to view and manage your events.")
                .font(.system(size: 16))
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingPermissionAlert = true
            }) {
                Text("Open Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CMColor.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading calendar events...")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func noEventsView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(CMColor.secondaryText)
            
            Text("No Events Found")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Text("No calendar events found in the selected date range.")
                .font(.system(size: 16))
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Action Methods
    
    private func addToWhiteList() {
        Task {
            let selectedEvents = getSelectedEvents()
            
            for event in selectedEvents {
                let matchingEvent = calendarService.events.first(where: { systemEvent in
                    let idMatches = systemEvent.eventIdentifier == event.originalEventIdentifier
                    let dateMatches = Calendar.current.isDate(systemEvent.startDate, inSameDayAs: event.date)
                    return idMatches && dateMatches
                })
                
                if let systemEvent = matchingEvent {
                    calendarService.addToWhiteList(systemEvent)
                }
            }
            
            await MainActor.run {
                selectedEventIds.removeAll()
            }
        }
    }
    
    private func removeFromWhiteList() {
        Task {
            let selectedEvents = getSelectedEvents()
            for event in selectedEvents {
                if let systemEvent = calendarService.events.first(where: {
                    $0.eventIdentifier == event.originalEventIdentifier &&
                    Calendar.current.isDate($0.startDate, inSameDayAs: event.date)
                }) {
                    calendarService.removeFromWhiteList(systemEvent)
                }
            }
            
            await MainActor.run {
                selectedEventIds.removeAll()
            }
        }
    }
    
    private func deleteSelectedEvents() {
        Task {
            let selectedEvents = getSelectedEvents()
            var systemEventsToDelete: [SystemCalendarEvent] = []
            var notFoundEvents: [CalendarEvent] = []
            
            for event in selectedEvents {
                if let systemEvent = calendarService.events.first(where: {
                    $0.eventIdentifier == event.originalEventIdentifier &&
                    Calendar.current.isDate($0.startDate, inSameDayAs: event.date)
                }) {
                    systemEventsToDelete.append(systemEvent)
                } else {
                    notFoundEvents.append(event)
                }
            }

            let result = await calendarService.deleteEvents(systemEventsToDelete)
            
            await MainActor.run {
                selectedEventIds.removeAll()
                
                var allFailedEvents: [(SystemCalendarEvent, EventDeletionError)] = result.failedEvents
                
                for notFoundEvent in notFoundEvents {
                    let tempSystemEvent = SystemCalendarEvent(
                        eventIdentifier: notFoundEvent.originalEventIdentifier,
                        title: notFoundEvent.title,
                        startDate: notFoundEvent.date,
                        endDate: notFoundEvent.date,
                        isAllDay: false,
                        calendar: notFoundEvent.source,
                        isMarkedAsSpam: false,
                        isWhiteListed: false
                    )
                    allFailedEvents.append((tempSystemEvent, .eventNotFound))
                }
                
                if !allFailedEvents.isEmpty {
                    cannotDeleteEvents = allFailedEvents
                    
                    if let firstCannotDelete = allFailedEvents.first {
                        cannotDeleteMessage = firstCannotDelete.1.localizedDescription
                    }
                    
                    showingCannotDeleteAlert = true
                } else {
                }
            }
        }
    }
    
    private func getSelectedEvents() -> [CalendarEvent] {
        return filteredEvents.filter { event in
            selectedEventIds.contains(event.eventIdentifier)
        }
    }
    
    private func filterName(for filter: CalendarFilter) -> String {
        switch filter {
        case .allEvents: return "All events"
        case .whiteList: return "White list"
        }
    }
}
