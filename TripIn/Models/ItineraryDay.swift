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
    /// Cached travel estimate between consecutive slots (count == slots.count - 1).
    var legEstimates: [String]? = nil
}

/// A saved trip: one or more days plus trip-level metadata. The unit stored in
/// Firestore. A single-day plan is just a Trip with `numberOfDays == 1`.
struct Trip: Codable, Identifiable {
    let id: String
    let city: String
    let startDate: String          // "yyyy-MM-dd"
    let numberOfDays: Int
    let dailyBudget: Double
    let currency: String
    let totalTripCost: String
    let days: [ItineraryDay]
    let createdAt: Date

    init(id: String = UUID().uuidString,
         city: String,
         startDate: String,
         numberOfDays: Int,
         dailyBudget: Double,
         currency: String = "IDR",
         totalTripCost: String,
         days: [ItineraryDay],
         createdAt: Date = Date()) {
        self.id = id
        self.city = city
        self.startDate = startDate
        self.numberOfDays = numberOfDays
        self.dailyBudget = dailyBudget
        self.currency = currency
        self.totalTripCost = totalTripCost
        self.days = days
        self.createdAt = createdAt
    }

    /// Wraps a single day (manual builder / chat result) into a 1-day trip.
    static func singleDay(_ day: ItineraryDay,
                          dailyBudget: Double = 0,
                          currency: String = "IDR") -> Trip {
        Trip(id: day.id, city: day.city, startDate: day.date, numberOfDays: 1,
             dailyBudget: dailyBudget, currency: currency,
             totalTripCost: day.totalEstimatedCost, days: [day], createdAt: day.createdAt)
    }
}
