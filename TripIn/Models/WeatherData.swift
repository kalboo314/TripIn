import Foundation

/// Full weather payload used by the ML recommender and agent tools.
struct WeatherData: Codable {
    let city: String
    let temperature: Double
    let humidity: Double
    let windSpeed: Double
    let precipitation: Double
    let uvIndex: Int
    let condition: String      // "Sunny", "Cloudy", "Rainy", "Snowy"
    let season: String         // "Spring", "Summer", "Autumn", "Winter"
    let location: String       // "coastal", "inland", "mountain"
}

/// Compact weather snapshot stored on an ItineraryDay.
struct WeatherSummary: Codable {
    let condition: String
    let temperature: Double
    let uvIndex: Int
    let recommendation: String
}
