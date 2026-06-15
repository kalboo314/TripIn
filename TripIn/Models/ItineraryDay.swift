import Foundation

struct ItineraryDay: Codable, Identifiable {
    let id: String
    let date: String
    let city: String
    let weather: WeatherSummary
    let slots: [TimeSlot]
    let packingList: [String]
    let totalEstimatedCost: String
    let createdAt: Date
}
