import Foundation
import CoreLocation

/// Estimates straight-line distance + rough travel time between consecutive
/// itinerary stops. Uses each slot's coordinate when present, otherwise geocodes
/// the slot's location/title (results cached in-memory).
final class TravelEstimator {
    static let shared = TravelEstimator()
    private init() {}

    private let geocoder = CLGeocoder()
    private var cache: [String: CLLocationCoordinate2D] = [:]

    /// One estimate string per consecutive pair (count == slots.count - 1).
    /// An empty string means "no estimate available".
    func legEstimates(for slots: [TimeSlot]) async -> [String] {
        guard slots.count > 1 else { return [] }

        var coords: [CLLocationCoordinate2D?] = []
        for slot in slots {
            if let c = slot.coordinate {
                coords.append(c)
            } else {
                coords.append(await coordinate(for: slot))
            }
        }

        var legs: [String] = []
        for i in 0..<(slots.count - 1) {
            guard let a = coords[i], let b = coords[i + 1] else { legs.append(""); continue }
            let meters = CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            legs.append(estimateString(meters: meters))
        }
        return legs
    }

    private func coordinate(for slot: TimeSlot) async -> CLLocationCoordinate2D? {
        let query = slot.location.isEmpty
            ? slot.title
            : "\(slot.title), \(slot.location)"
        let key = query.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        if let cached = cache[key] { return cached }

        let placemarks = try? await geocoder.geocodeAddressString(key)
        if let coordinate = placemarks?.first?.location?.coordinate {
            cache[key] = coordinate
            return coordinate
        }
        return nil
    }

    private func estimateString(meters: Double) -> String {
        guard meters >= 50 else { return "" }       // essentially the same spot
        let km = meters / 1000

        // Assume ~25 km/h average urban travel.
        let minutes = max(1, Int((km / 25.0) * 60))
        if km < 1 {
            return "🚶 \(Int(meters)) m · ~\(minutes) min"
        }
        return String(format: "🚗 ~%.1f km · ~%d min", km, minutes)
    }
}
