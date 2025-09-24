import Foundation
import EventKit
import Combine

@MainActor
final class AICalendarAgent: ObservableObject {
    
    enum Constants {
        static let spamMarker = "[MARKED_AS_SPAM]"
        static let backupIdentifierSeparator = "_"
    }
        
    @Published var events: [AICalendarSystemEvent] = []
    @Published var isLoading = false
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    private let eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    private let whitelistCalendarService = WhitelistCalendarService()
        
    init() {
        checkAuthorizationStatus()
        setupWhitelistObserver()
    }
        
    func requestCalendarAccess() async {
        let accessType = EKEntityType.event
        let isAccessGranted: Bool
        
        do {
            if #available(iOS 17.0, *) {
                isAccessGranted = try await eventStore.requestFullAccessToEvents()
            } else {
                isAccessGranted = try await eventStore.requestAccess(to: accessType)
            }
            
            await handleAccessResult(granted: isAccessGranted)
        } catch {
            await handleAccessError(error)
        }
    }
    
    func loadEvents(from startDate: Date? = nil, to endDate: Date? = nil) async {
        guard canAccessCalendar else {
            return await requestCalendarAccess()
        }
        
        isLoading = true
        errorMessage = nil
        
        let start = startDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let end = endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
        
        let whitelistedIdentifiers = whitelistCalendarService.getWhitelistedEventIdentifiers()
        
        let systemEvents = ekEvents.map {
            let compositeId = "\($0.eventIdentifier ?? "")_\($0.startDate.timeIntervalSince1970)"
            let isWhitelisted = whitelistedIdentifiers.contains(compositeId)
            return AICalendarSystemEvent(from: $0, isWhitelisted: isWhitelisted)
        }.sorted(by: { $0.startDate > $1.startDate })
        
        events = systemEvents
        isLoading = false
        updateEventsWhitelistStatus()
    }
    
    func deleteEvent(_ event: AICalendarSystemEvent) async -> AICalendarEventDeletionResult {
        guard canAccessCalendar else { return .failed(.noPermission) }
        
        guard let ekEvent = eventStore.event(withIdentifier: event.eventIdentifier) else {
            return .failed(.eventNotFound)
        }
        
        guard ekEvent.isDeletable() else {
            return .failed(.cannotDelete(reason: ekEvent.deletionRestrictionReason()))
        }
        
        do {
            try eventStore.remove(ekEvent, span: .thisEvent)
            events.removeAll { $0.id == event.id }
            return .success
        } catch {
            errorMessage = "Failed to delete event: \(error.localizedDescription)"
            return .failed(.systemError(error))
        }
    }
    
    func deleteEvents(_ eventsToDelete: [AICalendarSystemEvent]) async -> AICalendarDeletionResult {
        var deletedCount = 0
        var failedEvents: [(AICalendarSystemEvent, AICalendarDeletionError)] = []
        
        for event in eventsToDelete {
            let result = await deleteEvent(event)
            if case let .failed(error) = result {
                failedEvents.append((event, error))
            } else {
                deletedCount += 1
            }
        }
        
        return AICalendarDeletionResult(
            deletedCount: deletedCount,
            totalCount: eventsToDelete.count,
            failedEvents: failedEvents
        )
    }
    
    func markAsSpam(_ event: AICalendarSystemEvent) async -> Bool {
        guard canAccessCalendar, let ekEvent = eventStore.event(withIdentifier: event.eventIdentifier) else {
            return false
        }
        
        do {
            ekEvent.notes = (ekEvent.notes ?? "") + "\n\(Constants.spamMarker)"
            try eventStore.save(ekEvent, span: .thisEvent)
            
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].isMarkedAsSpam = true
            }
            return true
        } catch {
            errorMessage = "Failed to mark event as spam: \(error.localizedDescription)"
            return false
        }
    }
    
    func addToWhiteList(_ event: AICalendarSystemEvent) {
        whitelistCalendarService.addToWhitelist(event)
        updateEventsWhitelistStatus()
    }
    
    func removeFromWhiteList(_ event: AICalendarSystemEvent) {
        whitelistCalendarService.removeFromWhitelist(event)
        updateEventsWhitelistStatus()
    }
    
    func getEventsStatistics() -> EventsAICalendarStatistics {
        let spamCount = events.filter { $0.isMarkedAsSpam }.count
        let whitelistedCount = events.filter { $0.isWhiteListed }.count
        
        return EventsAICalendarStatistics(
            total: events.count,
            spam: spamCount,
            whitelisted: whitelistedCount,
            regular: events.count - spamCount - whitelistedCount
        )
    }
        
    private var canAccessCalendar: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }
    
    private func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if canAccessCalendar {
            Task { await loadEvents() }
        }
    }
    
    private func setupWhitelistObserver() {
        whitelistCalendarService.$whitelistedEvents
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateEventsWhitelistStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateEventsWhitelistStatus() {
        let whitelistedIdentifiers = whitelistCalendarService.getWhitelistedEventIdentifiers()
        
        for index in events.indices {
            let compositeIdentifier = events[index].eventIdentifier
            let isWhitelisted = whitelistedIdentifiers.contains(compositeIdentifier)
            
            guard events[index].isWhiteListed != isWhitelisted else { continue }
            
            events[index].isWhiteListed = isWhitelisted
            
            if isWhitelisted {
                events[index].isMarkedAsSpam = false
            }
        }
    }
    
    private func handleAccessResult(granted: Bool) async {
        if #available(iOS 17.0, *) {
            authorizationStatus = granted ? .fullAccess : .denied
            if granted {
                await loadEvents()
            }
        }
    }
    
    private func handleAccessError(_ error: Error) async {
        errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
        authorizationStatus = .denied
    }
}
