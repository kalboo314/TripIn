import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var city: String = ""
    @Published var date: Date = Date()
    @Published var results: [Attraction] = []
    @Published var weather: WeatherData?
    @Published var recommendedCategory: String?
    @Published var isLoading: Bool = false
    @Published var hasSearched: Bool = false
    @Published var errorMessage: String?

    /// Places the user has picked to assemble their own itinerary.
    @Published var draft: [Attraction] = []

    func toggleDraft(_ attraction: Attraction) {
        if let index = draft.firstIndex(where: { $0.id == attraction.id }) {
            draft.remove(at: index)
        } else {
            draft.append(attraction)
        }
    }

    func inDraft(_ attraction: Attraction) -> Bool {
        draft.contains { $0.id == attraction.id }
    }

    func clearDraft() { draft.removeAll() }

    func weatherSummary() -> WeatherSummary {
        WeatherSummary(
            condition: weather?.condition ?? "",
            temperature: weather?.temperature ?? 0,
            uvIndex: weather?.uvIndex ?? 0,
            recommendation: recommendedCategory ?? ""
        )
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Pipeline: weather forecast -> ML category -> Places search.
    func planMyDay() async {
        let trimmed = city.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        hasSearched = true
        isLoading = true
        defer { isLoading = false }

        let dateString = Self.dateFormatter.string(from: date)

        do {
            let forecast = try await WeatherService.shared.fetchForecast(city: trimmed, date: dateString)
            weather = forecast

            let category = MLRecommender.shared.predict(weather: forecast)
            recommendedCategory = category

            results = try await PlacesService.shared.searchAttractions(category: category,
                                                                       city: trimmed,
                                                                       limit: 10)
        } catch {
            results = []
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Something went wrong. Please try again."
        }
    }
}
