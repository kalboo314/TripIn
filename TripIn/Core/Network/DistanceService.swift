import Foundation

/// Real road distance/time between consecutive itinerary stops via Google's
/// Distance Matrix API. Bills only consecutive legs (N-1 elements per day), and
/// results are baked into the saved Trip so each trip is computed only once.
final class DistanceService {
    static let shared = DistanceService()
    private init() {}

    private let baseURL = "https://maps.googleapis.com/maps/api/distancematrix/json"
    private var cache: [String: String] = [:]

    /// Returns a copy of `trip` with each day's `legEstimates` filled in.
    func enrich(_ trip: Trip) async -> Trip {
        var days: [ItineraryDay] = []
        for day in trip.days {
            var enriched = day
            enriched.legEstimates = await legEstimates(for: day.slots)
            days.append(enriched)
        }
        return Trip(
            id: trip.id, city: trip.city, startDate: trip.startDate,
            numberOfDays: trip.numberOfDays, dailyBudget: trip.dailyBudget,
            currency: trip.currency, totalTripCost: trip.totalTripCost,
            days: days, createdAt: trip.createdAt
        )
    }

    /// One estimate string per consecutive pair (count == slots.count - 1).
    func legEstimates(for slots: [TimeSlot]) async -> [String] {
        guard slots.count > 1 else { return [] }
        var legs: [String] = []
        for i in 0..<(slots.count - 1) {
            legs.append(await leg(from: slots[i], to: slots[i + 1]))
        }
        return legs
    }

    // MARK: - Single leg (1 origin × 1 destination = 1 billed element)

    private func leg(from a: TimeSlot, to b: TimeSlot) async -> String {
        let origin = point(a)
        let destination = point(b)
        guard !origin.isEmpty, !destination.isEmpty else { return "" }

        let key = "\(origin)|\(destination)"
        if let cached = cache[key] { return cached }

        guard var comp = URLComponents(string: baseURL) else { return "" }
        comp.queryItems = [
            URLQueryItem(name: "origins", value: origin),
            URLQueryItem(name: "destinations", value: destination),
            URLQueryItem(name: "mode", value: "driving"),
            URLQueryItem(name: "key", value: Config.placesKey)
        ]
        guard let url = comp.url else { return "" }

        guard
            let (data, _) = try? await URLSession.shared.data(from: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rows = json["rows"] as? [[String: Any]],
            let elements = rows.first?["elements"] as? [[String: Any]],
            let element = elements.first,
            (element["status"] as? String) == "OK",
            let distance = element["distance"] as? [String: Any],
            let duration = element["duration"] as? [String: Any],
            let distanceText = distance["text"] as? String,
            let durationText = duration["text"] as? String
        else { return "" }

        let result = "🚗 \(distanceText) · \(durationText)"
        cache[key] = result
        return result
    }

    /// Prefer exact coordinates ("lat,lng"); otherwise the place name + location
    /// (Distance Matrix geocodes text origins/destinations itself).
    private func point(_ slot: TimeSlot) -> String {
        if let c = slot.coordinate {
            return "\(c.latitude),\(c.longitude)"
        }
        let query = slot.location.isEmpty ? slot.title : "\(slot.title), \(slot.location)"
        return query.trimmingCharacters(in: .whitespaces)
    }
}
