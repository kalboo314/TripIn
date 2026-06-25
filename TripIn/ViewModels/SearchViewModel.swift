import Foundation
import CoreLocation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var city: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date()

    @Published var budgetEnabled: Bool = false
    @Published var dailyBudget: Double = 200000
    @Published var currency: String = "IDR"
    @Published var preferences: String = ""

    @Published var results: [Attraction] = []
    @Published var weather: WeatherData?
    @Published var recommendedCategory: String?
    @Published var isLoading: Bool = false
    @Published var hasSearched: Bool = false
    @Published var errorMessage: String?

    // Trip output (manual build or auto generation both flow through here).
    @Published var isGenerating: Bool = false
    @Published var generationStage: String = ""
    @Published var generatedTrip: Trip?
    @Published var generateError: String?

    /// Places the user picked for a manual itinerary.
    @Published var draft: [Attraction] = []

    /// Days in the selected date range, clamped to the 1–7 the forecast/agent support.
    var numberOfDays: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: max(endDate, startDate))
        let diff = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return min(max(diff + 1, 1), 7)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Manual: recommend places to pick from

    /// Weather forecast -> ML category -> Places search (for the start day).
    func planMyDay() async {
        let trimmed = city.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let dateString = Self.dateFormatter.string(from: startDate)
        do {
            let forecast = try await WeatherService.shared.fetchForecast(city: trimmed, date: dateString)
            weather = forecast
            let category = MLRecommender.shared.predict(weather: forecast)
            await searchAttractions(category: category, manageLoading: false)
        } catch {
            weather = nil
            results = []
            hasSearched = true
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Something went wrong. Please try again."
        }
    }

    func searchAttractions(category: String, manageLoading: Bool = true) async {
        let trimmed = city.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a city first, then search."
            return
        }
        recommendedCategory = category
        hasSearched = true
        errorMessage = nil
        if manageLoading { isLoading = true }
        defer { if manageLoading { isLoading = false } }
        do {
            results = try await PlacesService.shared.searchAttractions(category: category,
                                                                       city: trimmed, limit: 10)
        } catch {
            results = []
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Something went wrong. Please try again."
        }
    }

    /// Infers the local currency from the typed city/country and sets it.
    /// (User can still override via the picker afterward.)
    func autoDetectCurrency() {
        if let detected = Self.currency(forCity: city) { currency = detected }
    }

    private static func currency(forCity raw: String) -> String? {
        let q = raw.lowercased()
        guard q.count >= 2 else { return nil }
        for (keywords, code) in cityCurrencyTable where keywords.contains(where: { q.contains($0) }) {
            return code
        }
        return nil
    }

    private static let cityCurrencyTable: [([String], String)] = [
        (["hong kong", "hongkong"], "HKD"),
        (["indonesia", "jakarta", "bali", "bandung", "surabaya", "yogyakarta", "ubud"], "IDR"),
        (["japan", "tokyo", "osaka", "kyoto", "nagoya", "sapporo", "hokkaido"], "JPY"),
        (["china", "shanghai", "beijing", "shenzhen", "guangzhou", "chengdu", "xian"], "CNY"),
        (["singapore"], "SGD"),
        (["malaysia", "kuala lumpur", "penang", "johor", "langkawi"], "MYR"),
        (["thailand", "bangkok", "phuket", "chiang mai", "pattaya"], "THB"),
        (["vietnam", "hanoi", "ho chi minh", "saigon", "da nang"], "VND"),
        (["philippines", "manila", "cebu", "boracay"], "PHP"),
        (["south korea", "korea", "seoul", "busan"], "KRW"),
        (["india", "delhi", "mumbai", "bangalore", "jaipur", "goa"], "INR"),
        (["united arab emirates", "uae", "dubai", "abu dhabi"], "AED"),
        (["australia", "sydney", "melbourne", "brisbane", "perth", "gold coast"], "AUD"),
        (["new zealand", "auckland", "wellington", "queenstown"], "NZD"),
        (["united kingdom", "england", "london", "manchester", "edinburgh", "scotland"], "GBP"),
        (["canada", "toronto", "vancouver", "montreal", "banff"], "CAD"),
        (["switzerland", "zurich", "geneva", "interlaken"], "CHF"),
        (["united states", "usa", "new york", "los angeles", "san francisco", "chicago",
          "miami", "las vegas", "seattle", "boston", "hawaii", "honolulu", "orlando"], "USD"),
        (["france", "paris", "nice", "lyon", "germany", "berlin", "munich", "spain", "madrid",
          "barcelona", "italy", "rome", "milan", "venice", "florence", "netherlands", "amsterdam",
          "portugal", "lisbon", "porto", "greece", "athens", "santorini", "ireland", "dublin",
          "austria", "vienna", "belgium", "brussels", "euro"], "EUR")
    ]

    func toggleDraft(_ attraction: Attraction) {
        if let index = draft.firstIndex(where: { $0.id == attraction.id }) {
            draft.remove(at: index)
        } else {
            draft.append(attraction)
        }
    }

    func inDraft(_ attraction: Attraction) -> Bool { draft.contains { $0.id == attraction.id } }
    func clearDraft() { draft.removeAll() }

    /// Builds a Trip from the picked places, splitting them across the date range
    /// (~even per day), enriches travel legs, and presents it.
    func buildManual() async {
        guard !draft.isEmpty else { return }
        generateError = nil
        isGenerating = true
        defer { isGenerating = false }
        let durationEnriched = DurationEstimatorService.shared.enrich(trip: makeManualTrip())
        let trip = await DistanceService.shared.enrich(durationEnriched)
        clearDraft()
        generatedTrip = trip
    }

    // MARK: - Auto: agent generation

    func autoPlan(for userId: String) async {
        let trimmed = city.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        generateError = nil
        isGenerating = true
        generationStage = ""
        defer { isGenerating = false; generationStage = "" }

        let start = Self.dateFormatter.string(from: startDate)
        let budget = budgetEnabled ? dailyBudget : 0

        do {
            // Primary: multi-agent pipeline (Planner → Budget → Critic).
            var trip = try await TripAgentOrchestrator.shared.generate(
                city: trimmed, startDate: start, numberOfDays: numberOfDays,
                dailyBudget: budget, currency: currency, preferences: preferences,
                onStage: { [weak self] stage in self?.generationStage = stage })
            trip = DurationEstimatorService.shared.enrich(trip: trip)
            trip = await DistanceService.shared.enrich(trip)
            try? await FirestoreService.shared.saveTrip(trip, for: userId)
            generatedTrip = trip
        } catch {
            // Fallback: the single-agent tool-calling generator.
            do {
                generatedTrip = try await AgentService.shared.generateTrip(
                    city: trimmed, startDate: start, numberOfDays: numberOfDays,
                    dailyBudget: budget, currency: currency,
                    preferences: preferences, for: userId)
            } catch {
                generateError = (error as? LocalizedError)?.errorDescription
                    ?? "Could not build your trip. Please try again."
            }
        }
    }

    // MARK: - Manual trip assembly

    private func makeManualTrip() -> Trip {
        let days = numberOfDays
        let chunks = distribute(draft, into: days)
        let summary = weatherSummary()

        var itineraryDays: [ItineraryDay] = []
        for i in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: i, to: startDate) ?? startDate
            itineraryDays.append(ItineraryDay(
                id: UUID().uuidString,
                date: Self.dateFormatter.string(from: date),
                city: city,
                weather: summary,
                slots: makeSlots(chunks[i]),
                packingList: [],
                totalEstimatedCost: "Varies",
                createdAt: Date()
            ))
        }

        return Trip(
            id: UUID().uuidString, city: city,
            startDate: Self.dateFormatter.string(from: startDate),
            numberOfDays: days,
            dailyBudget: budgetEnabled ? dailyBudget : 0,
            currency: currency, totalTripCost: "Varies",
            days: itineraryDays, createdAt: Date()
        )
    }

    private func makeSlots(_ attractions: [Attraction]) -> [TimeSlot] {
        var minutes = 9 * 60
        var slots: [TimeSlot] = []
        for a in attractions {
            let coord = (a.latitude != 0 || a.longitude != 0)
                ? CLLocationCoordinate2D(latitude: a.latitude, longitude: a.longitude) : nil
            slots.append(TimeSlot(
                time: clock(minutes), endTime: clock(minutes + 120), type: .attraction,
                title: a.name, description: a.description, location: a.address,
                estimatedCost: a.estimatedCost, tip: "", durationMinutes: 120, coordinate: coord))
            minutes += 120
        }
        return slots
    }

    private func distribute(_ items: [Attraction], into n: Int) -> [[Attraction]] {
        let count = max(1, n)
        var result = Array(repeating: [Attraction](), count: count)
        for (i, item) in items.enumerated() { result[i % count].append(item) }
        return result
    }

    private func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    func weatherSummary() -> WeatherSummary {
        WeatherSummary(
            condition: weather?.condition ?? "",
            temperature: weather?.temperature ?? 0,
            uvIndex: weather?.uvIndex ?? 0,
            recommendation: recommendedCategory ?? ""
        )
    }
}
