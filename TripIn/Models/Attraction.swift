import Foundation

struct Attraction: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let description: String
    let address: String
    let photoUrl: String
    let estimatedCost: String
    let openingHours: String
    let rating: Double
    let latitude: Double
    let longitude: Double
}
