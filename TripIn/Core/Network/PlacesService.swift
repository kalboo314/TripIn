import Foundation

enum PlacesError: LocalizedError {
    case network
    case decoding
    case noResults

    var errorDescription: String? {
        switch self {
        case .network:   return "Could not connect. Check your internet connection."
        case .decoding:  return "Something went wrong. Please try again."
        case .noResults: return "No attractions found. Try a different search."
        }
    }
}

final class PlacesService {
    static let shared = PlacesService()
    private init() {}

    private let textSearchURL   = "https://maps.googleapis.com/maps/api/place/textsearch/json"
    private let detailsURL      = "https://maps.googleapis.com/maps/api/place/details/json"
    private let photoURL        = "https://maps.googleapis.com/maps/api/place/photo"
    private let autocompleteURL = "https://maps.googleapis.com/maps/api/place/autocomplete/json"

    /// Strategy 2: cache full search results keyed by "category_city" so the
    /// same category+city is never fetched twice in a session (any limit reuses it).
    private var searchCache: [String: [Attraction]] = [:]

    /// City-autocomplete cache (last 10 queries → suggestions).
    private var autocompleteCache: [String: [CitysuggestionModel]] = [:]
    private var autocompleteOrder: [String] = []

    func searchAttractions(category: String, city: String, limit: Int) async throws -> [Attraction] {
        let cacheKey = "\(category.lowercased())_\(city.lowercased())"
        if let cached = searchCache[cacheKey] {
            return Array(cached.prefix(max(0, limit)))
        }

        guard var comp = URLComponents(string: textSearchURL) else { throw PlacesError.network }
        comp.queryItems = [
            URLQueryItem(name: "query", value: "\(category) in \(city)"),
            URLQueryItem(name: "key", value: Config.placesKey)
        ]
        guard let url = comp.url else { throw PlacesError.network }

        let data = try await fetch(url)
        let decoded: TextSearchResponse
        do { decoded = try JSONDecoder().decode(TextSearchResponse.self, from: data) }
        catch { throw PlacesError.decoding }

        guard !decoded.results.isEmpty else { throw PlacesError.noResults }

        let all = decoded.results.map { attraction(from: $0, fallbackCategory: category) }
        searchCache[cacheKey] = all
        return Array(all.prefix(max(0, limit)))
    }

    func attractionDetail(placeId: String) async throws -> Attraction {
        guard var comp = URLComponents(string: detailsURL) else { throw PlacesError.network }
        comp.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "fields",
                         value: "place_id,name,formatted_address,opening_hours,price_level,rating,photos,geometry,types"),
            URLQueryItem(name: "key", value: Config.placesKey)
        ]
        guard let url = comp.url else { throw PlacesError.network }

        let data = try await fetch(url)
        let decoded: DetailsResponse
        do { decoded = try JSONDecoder().decode(DetailsResponse.self, from: data) }
        catch { throw PlacesError.decoding }

        guard let result = decoded.result else { throw PlacesError.noResults }
        return attraction(from: result, placeId: placeId)
    }

    /// Google Places Autocomplete restricted to cities. Returns up to 5
    /// suggestions; [] for queries under 2 chars. Cached per query (last 10).
    func fetchCitySuggestions(query: String) async throws -> [CitysuggestionModel] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }

        let key = trimmed.lowercased()
        if let cached = autocompleteCache[key] { return cached }

        guard var comp = URLComponents(string: autocompleteURL) else { throw PlacesError.network }
        comp.queryItems = [
            URLQueryItem(name: "input", value: trimmed),
            URLQueryItem(name: "types", value: "(cities)"),
            URLQueryItem(name: "key", value: Config.placesKey)
        ]
        guard let url = comp.url else { throw PlacesError.network }

        let data = try await fetch(url)
        let decoded: AutocompleteResponse
        do { decoded = try JSONDecoder().decode(AutocompleteResponse.self, from: data) }
        catch { throw PlacesError.decoding }

        let suggestions = decoded.predictions.prefix(5).map { p -> CitysuggestionModel in
            let cityName = p.structured_formatting?.main_text
                ?? p.description.components(separatedBy: ",").first
                ?? p.description
            return CitysuggestionModel(id: p.place_id, cityName: cityName, fullName: p.description)
        }
        let result = Array(suggestions)

        autocompleteCache[key] = result
        autocompleteOrder.append(key)
        if autocompleteOrder.count > 10 {
            let oldest = autocompleteOrder.removeFirst()
            autocompleteCache[oldest] = nil
        }
        return result
    }

    // MARK: - Networking

    private func fetch(_ url: URL) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw PlacesError.network
            }
            return data
        } catch let error as PlacesError {
            throw error
        } catch {
            throw PlacesError.network
        }
    }

    // MARK: - Mapping

    private func attraction(from r: PlaceResult,
                            fallbackCategory: String? = nil,
                            placeId: String? = nil) -> Attraction {
        let loc = r.geometry?.location
        let typeLabel = r.types?.first?.replacingOccurrences(of: "_", with: " ")
        return Attraction(
            id: placeId ?? r.place_id ?? UUID().uuidString,
            name: r.name ?? "Unknown",
            category: fallbackCategory ?? typeLabel ?? "attraction",
            description: (r.types ?? [])
                .prefix(3)
                .map { $0.replacingOccurrences(of: "_", with: " ") }
                .joined(separator: ", "),
            address: r.formatted_address ?? "",
            photoUrl: photoURLString(for: r.photos?.first?.photo_reference),
            estimatedCost: mapPriceLevel(r.price_level),
            openingHours: openingHoursText(r.opening_hours),
            rating: r.rating ?? 0,
            latitude: loc?.lat ?? 0,
            longitude: loc?.lng ?? 0
        )
    }

    private func photoURLString(for ref: String?) -> String {
        guard let ref = ref, !ref.isEmpty else { return "" }
        var comp = URLComponents(string: photoURL)
        comp?.queryItems = [
            URLQueryItem(name: "maxwidth", value: "600"),
            URLQueryItem(name: "photo_reference", value: ref),
            URLQueryItem(name: "key", value: Config.placesKey)
        ]
        return comp?.url?.absoluteString ?? ""
    }

    private func openingHoursText(_ hours: OpeningHours?) -> String {
        if let weekday = hours?.weekday_text, !weekday.isEmpty {
            return weekday.joined(separator: "\n")
        }
        if let openNow = hours?.open_now {
            return openNow ? "Open now" : "Closed"
        }
        return ""
    }

    private func mapPriceLevel(_ level: Int?) -> String {
        switch level {
        case 0:  return "Free"
        case 1:  return "$"
        case 2:  return "$$"
        case 3:  return "$$$"
        case 4:  return "$$$$"
        default: return "Varies"
        }
    }
}

// MARK: - Google Places response shapes

private struct TextSearchResponse: Decodable {
    let results: [PlaceResult]
    let status: String?
}

private struct DetailsResponse: Decodable {
    let result: PlaceResult?
    let status: String?
}

private struct PlaceResult: Decodable {
    let place_id: String?
    let name: String?
    let formatted_address: String?
    let rating: Double?
    let price_level: Int?
    let types: [String]?
    let geometry: Geometry?
    let photos: [Photo]?
    let opening_hours: OpeningHours?
}

private struct Geometry: Decodable {
    let location: LocationLatLng?
}

private struct LocationLatLng: Decodable {
    let lat: Double
    let lng: Double
}

private struct Photo: Decodable {
    let photo_reference: String?
}

private struct OpeningHours: Decodable {
    let open_now: Bool?
    let weekday_text: [String]?
}

// MARK: - City autocomplete

/// A city suggestion from Google Places Autocomplete.
struct CitysuggestionModel: Identifiable {
    let id: String          // Google Places prediction placeId
    let cityName: String    // "Bali"
    let fullName: String    // "Bali, Indonesia"
}

private struct AutocompleteResponse: Decodable {
    let predictions: [Prediction]
    let status: String?
}

private struct Prediction: Decodable {
    let place_id: String
    let description: String
    let structured_formatting: StructuredFormatting?
}

private struct StructuredFormatting: Decodable {
    let main_text: String
}
