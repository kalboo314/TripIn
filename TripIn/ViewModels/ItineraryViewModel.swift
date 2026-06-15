import Foundation

@MainActor
final class ItineraryViewModel: ObservableObject {
    @Published var isSaving: Bool = false
    @Published var didSave: Bool = false
    @Published var errorMessage: String?

    func save(_ trip: ItineraryDay, for userId: String) async {
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
    func shareSummary(_ trip: ItineraryDay) -> String {
        var lines: [String] = [
            "TripIn — \(trip.city) (\(trip.date))",
            "Weather: \(trip.weather.condition), \(Int(trip.weather.temperature))°C",
            ""
        ]
        for slot in trip.slots {
            lines.append("\(slot.time)–\(slot.endTime)  \(slot.title)  [\(slot.estimatedCost)]")
        }
        lines.append("")
        if !trip.packingList.isEmpty {
            lines.append("Packing: \(trip.packingList.joined(separator: ", "))")
        }
        lines.append("Total: \(trip.totalEstimatedCost)")
        return lines.joined(separator: "\n")
    }
}
