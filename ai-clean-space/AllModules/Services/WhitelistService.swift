import Foundation
import CoreData
import Combine

@MainActor
final class WhitelistCalendarService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var whitelistedEvents: [AICalendarSystemEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let whitelistKey = "whitelistedEvents"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadWhitelistedEvents()
    }
    
    // MARK: - Public Methods
    
    func addToWhitelist(_ event: AICalendarSystemEvent) {
        if isEventWhitelisted(event) {
            return
        }
        
        var eventToAdd = event
        eventToAdd.isWhiteListed = true
        whitelistedEvents.append(eventToAdd)
        saveWhitelistedEvents()
    }
    
    func removeFromWhitelist(_ event: AICalendarSystemEvent) {
        whitelistedEvents.removeAll { $0.eventIdentifier == event.eventIdentifier }
        saveWhitelistedEvents()
    }
    
    func isEventWhitelisted(_ event: AICalendarSystemEvent) -> Bool {
        return whitelistedEvents.contains { $0.eventIdentifier == event.eventIdentifier }
    }
    
    func getWhitelistedEventIdentifiers() -> Set<String> {
        let identifiers = Set(whitelistedEvents.map { $0.eventIdentifier })
        return identifiers
    }
    
    func clearWhitelist() {
        whitelistedEvents = []
        saveWhitelistedEvents()
    }
    
    // MARK: - Private Methods
    
    private func saveWhitelistedEvents() {
        do {
            let encodedData = try JSONEncoder().encode(whitelistedEvents)
            userDefaults.set(encodedData, forKey: whitelistKey)
        } catch {
            errorMessage = "Failed to save whitelist: \(error.localizedDescription)"
        }
    }
    
    private func loadWhitelistedEvents() {
        isLoading = true
        errorMessage = nil
        
        if let savedData = userDefaults.data(forKey: whitelistKey) {
            do {
                whitelistedEvents = try JSONDecoder().decode([AICalendarSystemEvent].self, from: savedData)
            } catch {
                errorMessage = "Failed to load whitelist: \(error.localizedDescription)"
                whitelistedEvents = []
            }
        } else {
            whitelistedEvents = []
        }
        
        isLoading = false
    }
}
