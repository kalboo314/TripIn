import Foundation
import CoreLocation

enum SlotType: String, Codable {
    case attraction
    case meal
    case travel
    case rest
}

struct TimeSlot: Codable, Identifiable {
    let id: String
    let time: String
    var endTime: String
    let type: SlotType
    let title: String
    let description: String
    let location: String
    let estimatedCost: String
    let tip: String
    var durationMinutes: Int
    let coordinate: CLLocationCoordinate2D?

    // ML duration enrichment (DurationEstimator).
    var durationDisplay: String?      // e.g. "2 – 3 hrs"
    var mlPredictedMinutes: Int?      // raw minutes from ML prediction

    init(
        id: String = UUID().uuidString,
        time: String,
        endTime: String,
        type: SlotType,
        title: String,
        description: String,
        location: String,
        estimatedCost: String,
        tip: String,
        durationMinutes: Int,
        coordinate: CLLocationCoordinate2D? = nil,
        durationDisplay: String? = nil,
        mlPredictedMinutes: Int? = nil
    ) {
        self.id = id
        self.time = time
        self.endTime = endTime
        self.type = type
        self.title = title
        self.description = description
        self.location = location
        self.estimatedCost = estimatedCost
        self.tip = tip
        self.durationMinutes = durationMinutes
        self.coordinate = coordinate
        self.durationDisplay = durationDisplay
        self.mlPredictedMinutes = mlPredictedMinutes
    }

    // CLLocationCoordinate2D isn't Codable, so we flatten it to lat/lng.
    private enum CodingKeys: String, CodingKey {
        case id, time, endTime, type, title, description
        case location, estimatedCost, tip, durationMinutes
        case latitude, longitude
        case durationDisplay, mlPredictedMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        time = try c.decode(String.self, forKey: .time)
        endTime = try c.decode(String.self, forKey: .endTime)
        type = try c.decode(SlotType.self, forKey: .type)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decode(String.self, forKey: .description)
        location = try c.decode(String.self, forKey: .location)
        estimatedCost = try c.decode(String.self, forKey: .estimatedCost)
        tip = try c.decode(String.self, forKey: .tip)
        durationMinutes = try c.decode(Int.self, forKey: .durationMinutes)
        if let lat = try c.decodeIfPresent(Double.self, forKey: .latitude),
           let lng = try c.decodeIfPresent(Double.self, forKey: .longitude) {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            coordinate = nil
        }
        durationDisplay = try c.decodeIfPresent(String.self, forKey: .durationDisplay)
        mlPredictedMinutes = try c.decodeIfPresent(Int.self, forKey: .mlPredictedMinutes)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(time, forKey: .time)
        try c.encode(endTime, forKey: .endTime)
        try c.encode(type, forKey: .type)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(location, forKey: .location)
        try c.encode(estimatedCost, forKey: .estimatedCost)
        try c.encode(tip, forKey: .tip)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encodeIfPresent(coordinate?.latitude, forKey: .latitude)
        try c.encodeIfPresent(coordinate?.longitude, forKey: .longitude)
        try c.encodeIfPresent(durationDisplay, forKey: .durationDisplay)
        try c.encodeIfPresent(mlPredictedMinutes, forKey: .mlPredictedMinutes)
    }
}
