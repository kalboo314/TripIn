import Foundation
import CoreLocation

/// Backs both "build a new itinerary from search picks" and "edit an existing trip".
@MainActor
final class TripBuilderViewModel: ObservableObject {
    @Published var city: String
    @Published var date: Date
    @Published var slots: [TimeSlot]
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    private let existingTripId: String?   // non-nil when editing a saved trip
    private let createdAt: Date
    private let weather: WeatherSummary
    private let packingList: [String]
    private let dailyBudget: Double
    private let currency: String
    private let totalCost: String

    var isEditing: Bool { existingTripId != nil }

    private init(city: String, date: Date, slots: [TimeSlot], weather: WeatherSummary,
                 packingList: [String], dailyBudget: Double, currency: String,
                 totalCost: String, existingTripId: String?, createdAt: Date) {
        self.city = city
        self.date = date
        self.slots = slots
        self.weather = weather
        self.packingList = packingList
        self.dailyBudget = dailyBudget
        self.currency = currency
        self.totalCost = totalCost
        self.existingTripId = existingTripId
        self.createdAt = createdAt
    }

    // MARK: - Factories

    static func newFromAttractions(city: String, date: Date,
                                   attractions: [Attraction],
                                   weather: WeatherSummary) -> TripBuilderViewModel {
        let vm = TripBuilderViewModel(city: city, date: date, slots: [], weather: weather,
                                      packingList: [], dailyBudget: 0, currency: "IDR",
                                      totalCost: "Varies", existingTripId: nil, createdAt: Date())
        vm.slots = attractions.map { vm.makeSlot(from: $0) }
        vm.recomputeTimes()
        return vm
    }

    /// Edits an existing (single-day) trip. Only the first day is editable here.
    static func edit(_ trip: Trip) -> TripBuilderViewModel {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let day = trip.days.first
        return TripBuilderViewModel(
            city: trip.city,
            date: formatter.date(from: trip.startDate) ?? Date(),
            slots: day?.slots ?? [],
            weather: day?.weather ?? WeatherSummary(condition: "", temperature: 0, uvIndex: 0, recommendation: ""),
            packingList: day?.packingList ?? [],
            dailyBudget: trip.dailyBudget,
            currency: trip.currency,
            totalCost: trip.totalTripCost,
            existingTripId: trip.id,
            createdAt: trip.createdAt
        )
    }

    // MARK: - Editing

    func addAttraction(_ attraction: Attraction) {
        slots.append(makeSlot(from: attraction))
        recomputeTimes()
    }

    func replace(slotId: String, with attraction: Attraction) {
        guard let index = slots.firstIndex(where: { $0.id == slotId }) else { return }
        slots[index] = makeSlot(from: attraction)
        recomputeTimes()
    }

    func remove(at offsets: IndexSet) {
        slots.remove(atOffsets: offsets)
        recomputeTimes()
    }

    func move(from source: IndexSet, to destination: Int) {
        slots.move(fromOffsets: source, toOffset: destination)
        recomputeTimes()
    }

    // MARK: - Saving

    func save(for userId: String) async -> Bool {
        guard !slots.isEmpty else {
            errorMessage = "Add at least one place to your itinerary."
            return false
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let trip = await DistanceService.shared.enrich(buildTrip())
            try await FirestoreService.shared.saveTrip(trip, for: userId)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not save trip. Please try again."
            return false
        }
    }

    func buildTrip() -> Trip {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let day = ItineraryDay(
            id: UUID().uuidString,
            date: dateString,
            city: city,
            weather: weather,
            slots: slots,
            packingList: packingList,
            totalEstimatedCost: totalCost,
            createdAt: createdAt
        )
        return Trip(
            id: existingTripId ?? UUID().uuidString,
            city: city,
            startDate: dateString,
            numberOfDays: 1,
            dailyBudget: dailyBudget,
            currency: currency,
            totalTripCost: totalCost,
            days: [day],
            createdAt: createdAt
        )
    }

    // MARK: - Helpers

    private func makeSlot(from attraction: Attraction) -> TimeSlot {
        let coordinate = (attraction.latitude != 0 || attraction.longitude != 0)
            ? CLLocationCoordinate2D(latitude: attraction.latitude, longitude: attraction.longitude)
            : nil
        return TimeSlot(
            time: "09:00", endTime: "11:00", type: .attraction,
            title: attraction.name, description: attraction.description,
            location: attraction.address, estimatedCost: attraction.estimatedCost,
            tip: "", durationMinutes: 120, coordinate: coordinate
        )
    }

    /// Lays slots back-to-back from 09:00, preserving each slot's duration.
    private func recomputeTimes() {
        var minutes = 9 * 60
        slots = slots.map { slot in
            let updated = TimeSlot(
                id: slot.id,
                time: clock(minutes), endTime: clock(minutes + slot.durationMinutes),
                type: slot.type, title: slot.title, description: slot.description,
                location: slot.location, estimatedCost: slot.estimatedCost,
                tip: slot.tip, durationMinutes: slot.durationMinutes, coordinate: slot.coordinate
            )
            minutes += slot.durationMinutes
            return updated
        }
    }

    private func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }
}
