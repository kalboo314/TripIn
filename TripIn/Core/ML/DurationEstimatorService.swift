import CoreML
import Foundation

class DurationEstimatorService {

    // MARK: - Singleton
    static let shared = DurationEstimatorService()

    // MARK: - Model
    private var model: DurationEstimator?

    private init() {
        do {
            model = try DurationEstimator(configuration: MLModelConfiguration())
        } catch {
            print("[DurationEstimatorService] Failed to load: \(error)")
        }
    }

    // MARK: - Prediction

    func predictDuration(
        category: String,
        rating: Double,
        crowdLevel: Int,
        userPace: UserPace,
        isWeekend: Bool,
        season: String,
        attractionSize: AttractionSize
    ) -> PredictionResult {

        guard let model = model else { return fallback(for: category) }

        do {
            let input = DurationEstimatorInput(
                attraction_category: category,
                attraction_rating: rating,
                crowd_level: Double(crowdLevel),
                user_pace: userPace.rawValue,
                is_weekend: isWeekend ? 1.0 : 0.0,
                season: season,
                attraction_size: attractionSize.rawValue
            )
            let output = try model.prediction(input: input)
            let clamped = max(0.5, min(6.0, output.estimated_hours))
            return PredictionResult(hours: clamped)
        } catch {
            print("[DurationEstimatorService] Prediction error: \(error)")
            return fallback(for: category)
        }
    }

    /// Convenience — takes the existing Attraction model directly.
    func predictDuration(for attraction: Attraction, userPace: UserPace, date: Date) -> PredictionResult {
        let isWeekend = Calendar.current.isDateInWeekend(date)
        return predictDuration(
            category: attraction.category,
            rating: attraction.rating,
            crowdLevel: estimateCrowd(rating: attraction.rating, isWeekend: isWeekend),
            userPace: userPace,
            isWeekend: isWeekend,
            season: Self.season(from: date),
            attractionSize: attractionSize(from: attraction.category)
        )
    }

    // MARK: - Trip enrichment

    /// Returns a copy of `trip` where every attraction slot has an ML-predicted
    /// duration (durationMinutes + durationDisplay + mlPredictedMinutes) and a
    /// recalculated endTime. Non-attraction slots are left untouched.
    func enrich(trip: Trip) -> Trip {
        let pace = Self.currentPace()
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current

        let days = trip.days.map { day -> ItineraryDay in
            let date = formatter.date(from: day.date) ?? Date()
            let isWeekend = calendar.isDateInWeekend(date)
            let seasonStr = Self.season(from: date)
            let category = day.weather.recommendation.isEmpty ? "outdoor" : day.weather.recommendation

            let slots = day.slots.map { slot -> TimeSlot in
                guard slot.type == .attraction else { return slot }
                let result = predictDuration(
                    category: category, rating: 4.0,
                    crowdLevel: crowdLevel(fromTime: slot.time), userPace: pace,
                    isWeekend: isWeekend, season: seasonStr, attractionSize: .medium)
                var updated = slot
                updated.mlPredictedMinutes = result.minutes
                updated.durationDisplay = result.display
                updated.durationMinutes = result.minutes
                updated.endTime = Self.addMinutes(to: slot.time, minutes: result.minutes)
                return updated
            }
            return ItineraryDay(
                id: day.id, date: day.date, city: day.city, weather: day.weather,
                slots: slots, packingList: day.packingList,
                totalEstimatedCost: day.totalEstimatedCost, createdAt: day.createdAt,
                legEstimates: day.legEstimates)
        }
        return Trip(
            id: trip.id, city: trip.city, startDate: trip.startDate,
            numberOfDays: trip.numberOfDays, dailyBudget: trip.dailyBudget,
            currency: trip.currency, totalTripCost: trip.totalTripCost,
            days: days, createdAt: trip.createdAt)
    }

    // MARK: - Helpers

    static func currentPace() -> UserPace {
        let raw = UserDefaults.standard.string(forKey: "tripIn_userPace") ?? "moderate"
        return UserPace(rawValue: raw) ?? .moderate
    }

    static func season(from date: Date) -> String {
        switch Calendar.current.component(.month, from: date) {
        case 12, 1, 2: return "Winter"
        case 3, 4, 5:  return "Spring"
        case 6, 7, 8:  return "Summer"
        default:        return "Autumn"
        }
    }

    static func addMinutes(to time: String, minutes: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        guard let start = f.date(from: time) else { return time }
        return f.string(from: start.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    private func crowdLevel(fromTime time: String) -> Int {
        guard let hour = Int(time.prefix(2)) else { return 50 }
        switch hour {
        case 7...9:   return 25
        case 10...12: return 55
        case 13...15: return 75
        case 16...18: return 60
        default:      return 35
        }
    }

    private func estimateCrowd(rating: Double, isWeekend: Bool) -> Int {
        let base = isWeekend ? 65 : 40
        let boost = Int((rating - 3.0) * 10)
        return min(100, max(10, base + boost))
    }

    private func attractionSize(from category: String) -> AttractionSize {
        switch category {
        case "beach", "nature", "outdoor": return .large
        case "cultural":                   return .medium
        default:                           return .small
        }
    }

    private func fallback(for category: String) -> PredictionResult {
        let hours: [String: Double] = [
            "beach": 3.0, "nature": 2.5, "cultural": 1.5, "outdoor": 2.0, "indoor": 1.5
        ]
        return PredictionResult(hours: hours[category] ?? 2.0)
    }
}

// MARK: - Supporting Types

struct PredictionResult {
    let hours: Double

    var minutes: Int { Int(hours * 60) }

    var display: String {
        switch hours {
        case ..<1.0:     return "~\(Int(hours * 60)) min"
        case 1.0..<1.5:  return "~1 hr"
        case 1.5..<2.0:  return "1.5 – 2 hrs"
        case 2.0..<3.0:  return "2 – 3 hrs"
        case 3.0..<4.0:  return "3 – 4 hrs"
        case 4.0..<5.0:  return "4 – 5 hrs"
        default:          return "Half day"
        }
    }
}

enum UserPace: String, CaseIterable, Codable {
    case relaxed  = "relaxed"
    case moderate = "moderate"
    case fast     = "fast"

    var displayName: String {
        switch self {
        case .relaxed:  return "Relaxed 🧘"
        case .moderate: return "Moderate 🚶"
        case .fast:     return "Fast ⚡"
        }
    }

    var description: String {
        switch self {
        case .relaxed:  return "Enjoy every spot, no rushing"
        case .moderate: return "Balanced — see the highlights"
        case .fast:     return "Cover more ground, less time each"
        }
    }
}

enum AttractionSize: String {
    case small  = "small"
    case medium = "medium"
    case large  = "large"
}
