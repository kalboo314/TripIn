import Foundation

enum WeatherError: LocalizedError {
    case network
    case decoding
    case cityNotFound

    var errorDescription: String? {
        switch self {
        case .network:      return "Could not connect. Check your internet connection."
        case .decoding:     return "Something went wrong. Please try again."
        case .cityNotFound: return "We couldn't find that city. Check the spelling."
        }
    }
}

final class WeatherService {
    static let shared = WeatherService()
    private init() {}

    private let baseURL = "https://api.openweathermap.org/data/2.5/forecast"

    /// In-memory cache keyed by "city|date".
    private var cache: [String: WeatherData] = [:]

    /// `date` is expected as "yyyy-MM-dd".
    func fetchForecast(city: String, date: String) async throws -> WeatherData {
        let key = "\(city.lowercased())|\(date)"
        if let cached = cache[key] { return cached }

        guard var components = URLComponents(string: baseURL) else { throw WeatherError.network }
        components.queryItems = [
            URLQueryItem(name: "q", value: city),
            URLQueryItem(name: "appid", value: Config.weatherKey),
            URLQueryItem(name: "units", value: "metric")
        ]
        guard let url = components.url else { throw WeatherError.network }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw WeatherError.network
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { throw WeatherError.cityNotFound }
            guard (200...299).contains(http.statusCode) else { throw WeatherError.network }
        }

        let decoded: OWMForecastResponse
        do {
            decoded = try JSONDecoder().decode(OWMForecastResponse.self, from: data)
        } catch {
            throw WeatherError.decoding
        }

        guard let entry = selectEntry(from: decoded.list, date: date) else {
            throw WeatherError.decoding
        }

        let condition = mapCondition(entry.weather.first?.main ?? "")
        let month = monthIndex(from: date)

        let weatherData = WeatherData(
            city: decoded.city.name.isEmpty ? city : decoded.city.name,
            temperature: entry.main.temp,
            humidity: entry.main.humidity,
            windSpeed: entry.wind.speed,
            precipitation: (entry.pop ?? 0) * 100,   // pop is a 0...1 probability -> percent
            uvIndex: estimateUVIndex(condition: condition, month: month),
            condition: condition,
            season: season(for: month),
            location: locationType(for: city)
        )

        cache[key] = weatherData
        return weatherData
    }

    // MARK: - Forecast selection

    /// Picks the forecast slot on the requested day closest to midday;
    /// falls back to the nearest available slot if the date is out of range.
    private func selectEntry(from list: [OWMEntry], date: String) -> OWMEntry? {
        let sameDay = list.filter { $0.dt_txt.hasPrefix(date) }
        let pool = sameDay.isEmpty ? list : sameDay
        return pool.min { distanceToNoon($0.dt_txt) < distanceToNoon($1.dt_txt) } ?? pool.first
    }

    private func distanceToNoon(_ dtTxt: String) -> Int {
        // dtTxt format: "2025-07-15 12:00:00"
        let hour = Int(dtTxt.dropFirst(11).prefix(2)) ?? 0
        return abs(hour - 12)
    }

    // MARK: - Mapping helpers

    private func mapCondition(_ rawMain: String) -> String {
        switch rawMain.lowercased() {
        case "clear":                              return "Sunny"
        case "rain", "drizzle", "thunderstorm":    return "Rainy"
        case "snow":                               return "Snowy"
        case "clouds", "mist", "fog", "haze", "smoke": return "Cloudy"
        default:                                   return "Cloudy"
        }
    }

    private func monthIndex(from date: String) -> Int {
        if date.count >= 7, let m = Int(date.dropFirst(5).prefix(2)) { return m }
        return Calendar.current.component(.month, from: Date())
    }

    private func season(for month: Int) -> String {
        switch month {
        case 3...5:   return "Spring"
        case 6...8:   return "Summer"
        case 9...11:  return "Autumn"
        default:      return "Winter"
        }
    }

    /// The /forecast endpoint doesn't return UV, so we estimate from season + sky.
    private func estimateUVIndex(condition: String, month: Int) -> Int {
        let summer = (5...9).contains(month)
        switch condition {
        case "Sunny":  return summer ? 9 : 5
        case "Cloudy": return summer ? 5 : 3
        case "Rainy":  return 2
        case "Snowy":  return 1
        default:       return 3
        }
    }

    private func locationType(for city: String) -> String {
        let key = city.lowercased()
        let coastal: Set<String> = [
            "bali", "sydney", "miami", "barcelona", "rio de janeiro", "cape town",
            "mumbai", "penang", "da nang", "phuket", "nice", "honolulu",
            "lisbon", "dubai", "singapore"
        ]
        let mountain: Set<String> = [
            "denver", "zurich", "kathmandu", "cusco", "interlaken", "aspen",
            "banff", "queenstown", "chamonix", "innsbruck", "bandung", "genting"
        ]
        if coastal.contains(key)  { return "coastal" }
        if mountain.contains(key) { return "mountain" }
        return "inland"
    }
}

// MARK: - OpenWeatherMap response shapes

private struct OWMForecastResponse: Decodable {
    let list: [OWMEntry]
    let city: OWMCity
}

private struct OWMCity: Decodable {
    let name: String
}

private struct OWMEntry: Decodable {
    let dt_txt: String
    let main: OWMMain
    let wind: OWMWind
    let weather: [OWMWeather]
    let pop: Double?
}

private struct OWMMain: Decodable {
    let temp: Double
    let humidity: Double
}

private struct OWMWind: Decodable {
    let speed: Double
}

private struct OWMWeather: Decodable {
    let main: String
}
