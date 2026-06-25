import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var savedTrips: [Trip] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Location-based recommendations for the Home feed.
    @Published var recommendedPlaces: [Attraction] = []
    @Published var recommendedCity: String = ""
    @Published var isLoadingRecommended: Bool = false

    private let locationService = LocationService()
    private static let defaultCity = "Bali"
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    // MARK: - Saved trips

    func loadSavedTrips(for userId: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            savedTrips = try await FirestoreService.shared.fetchTrips(for: userId)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not load your trips. Please try again."
        }
    }

    func refresh(for userId: String) async {
        await loadSavedTrips(for: userId)
    }

    func delete(_ trip: Trip, for userId: String) async {
        do {
            try await FirestoreService.shared.deleteTrip(tripId: trip.id, for: userId)
            savedTrips.removeAll { $0.id == trip.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not delete trip. Please try again."
        }
    }

    // MARK: - Recommended places (current location → weather → ML → places)

    func loadRecommended() async {
        guard recommendedPlaces.isEmpty, !isLoadingRecommended else { return }
        isLoadingRecommended = true
        defer { isLoadingRecommended = false }

        // Try the user's current city; fall back to a popular default.
        var city = Self.defaultCity
        if let detected = try? await locationService.requestCurrentCity(),
           !detected.trimmingCharacters(in: .whitespaces).isEmpty {
            city = detected
        }

        if let places = try? await places(for: city), !places.isEmpty {
            recommendedCity = city
            recommendedPlaces = places
        } else if city != Self.defaultCity, let fallback = try? await places(for: Self.defaultCity) {
            recommendedCity = Self.defaultCity
            recommendedPlaces = fallback
        }
    }

    private func places(for city: String) async throws -> [Attraction] {
        let dateString = Self.dateFormatter.string(from: Date())
        let weather = try await WeatherService.shared.fetchForecast(city: city, date: dateString)
        let category = MLRecommender.shared.predict(weather: weather)
        return try await PlacesService.shared.searchAttractions(category: category, city: city, limit: 6)
    }
}
