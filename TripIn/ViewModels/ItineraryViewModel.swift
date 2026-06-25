import Foundation

@MainActor
final class ItineraryViewModel: ObservableObject {
    @Published var isSaving: Bool = false
    @Published var didSave: Bool = false
    @Published var errorMessage: String?

    func save(_ trip: Trip, for userId: String) async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await FirestoreService.shared.saveTrip(trip, for: userId)
            didSave = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not save trip. Please try again."
        }
    }

    /// Plain-text summary used by the Share button.
    func shareSummary(_ trip: Trip) -> String {
        var lines: [String] = ["TripIn — \(trip.city) (\(trip.startDate), \(trip.numberOfDays) day\(trip.numberOfDays > 1 ? "s" : ""))", ""]
        for (index, day) in trip.days.enumerated() {
            if trip.numberOfDays > 1 {
                lines.append("Day \(index + 1) — \(day.date) (\(day.weather.condition), \(Int(day.weather.temperature))°C)")
            }
            for slot in day.slots {
                lines.append("  \(slot.time)–\(slot.endTime)  \(slot.title)  [\(slot.estimatedCost)]")
            }
            lines.append("")
        }
        lines.append("Total: \(trip.totalTripCost)")
        return lines.joined(separator: "\n")
    }
}
