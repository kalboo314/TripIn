import Foundation

@MainActor
final class NearMeViewModel: ObservableObject {
    @Published var detectedCity: String = ""
    @Published var status: LocationService.LocationStatus = .idle
    @Published var attractions: [Attraction] = []
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false

    private let locationService = LocationService()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Full auto pipeline: location → reverse geocode → weather → ML category → places.
    func loadNearbyRecommendations() async {
        isLoading = true
        status = .locating
        errorMessage = ""
        defer { isLoading = false }

        do {
            let city = try await locationService.requestCurrentCity()
            detectedCity = city

            let dateString = Self.dateFormatter.string(from: Date())
            let weather = try await WeatherService.shared.fetchForecast(city: city, date: dateString)
            let category = MLRecommender.shared.predict(weather: weather)
            attractions = try await PlacesService.shared.searchAttractions(category: category,
                                                                           city: city, limit: 5)
            status = .done
        } catch let error as LocationService.LocationError {
            if case .permissionDenied = error { status = .denied } else { status = .error }
            errorMessage = error.errorDescription ?? "Something went wrong."
        } catch {
            status = .error
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not load nearby places. Please try again."
        }
    }

    /// Pre-fills AgentChatView with the detected city for full-day planning.
    var agentPrefilledCity: String { detectedCity }
}
