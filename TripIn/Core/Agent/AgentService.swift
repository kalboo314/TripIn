import Foundation

enum AgentError: LocalizedError {
    case maxIterationsExceeded
    case malformedJSON
    case missingToolCalls
    case network

    var errorDescription: String? {
        switch self {
        case .maxIterationsExceeded: return "Could not build itinerary. Please try again."
        case .malformedJSON:         return "Could not build itinerary. Please try again."
        case .missingToolCalls:      return "Could not build itinerary. Please try again."
        case .network:               return "Could not connect. Check your internet connection."
        }
    }
}

@MainActor
final class AgentService: ObservableObject {

    /// Human-readable progress shown in the chat UI.
    @Published var agentStatus: String = ""

    static let shared = AgentService()
    private init() {}

    private let baseURL = "https://api.deepseek.com/v1/chat/completions"
    private let model = "deepseek-chat"
    // The model often issues one tool call per round-trip, so a strict 8 isn't
    // enough even for compliant behaviour (≈9 needed). 12 keeps the loop bounded
    // while tolerating the model's pacing; redundant calls are curbed via the prompt.
    private let maxIterations = 12
    private let maxDetailCalls = 4
    private let targetDetailSlots = 3

    private var detailCallCount = 0
    /// Detail-call cap for the current run (4 for chat, 6 for multi-day trips).
    private var detailCap = 4
    /// Basic attraction info seen via search_attractions, used to reuse data
    /// once the detail cap is hit (Strategy 3) instead of more API calls.
    private var seenAttractions: [String: Attraction] = [:]

    private let systemPrompt = """
    You are a travel planning assistant. You MUST call tools in this exact order \
    before responding:
    1. get_weather_forecast
    2. run_ml_recommendation
    3. search_attractions
    4. get_attraction_detail (call this up to 4 times for different places)
    5. get_packing_tips
    Never skip any tool. Never answer without calling all tools first.
    Call each tool the minimum number of times: call search_attractions EXACTLY ONCE, \
    and never repeat get_weather_forecast, run_ml_recommendation or search_attractions. \
    Immediately after get_packing_tips, output the final JSON — do not call any more tools.
    Return the final result as a single JSON object \
    only, no extra text, no markdown backticks. The JSON must match this shape:
    {"date":"yyyy-MM-dd","city":"...","weather":{"condition":"...","temperature":0.0,\
    "uvIndex":0,"recommendation":"..."},"slots":[{"time":"08:00","endTime":"10:00",\
    "type":"attraction|meal|travel|rest","title":"...","description":"...",\
    "location":"...","estimatedCost":"...","tip":"...","durationMinutes":0}],\
    "packingList":["..."],"totalEstimatedCost":"..."}
    """

    /// Runs the agent loop and returns the assembled itinerary.
    ///
    /// The tool order is driven deterministically via a forced `tool_choice` for
    /// each step (deepseek-chat doesn't reliably self-sequence with "auto" — it
    /// issues redundant calls). Once all tools have run we force `tool_choice:
    /// "none"` so the model must emit the final JSON.
    func planTrip(userMessage: String) async throws -> ItineraryDay {
        detailCallCount = 0
        detailCap = maxDetailCalls
        seenAttractions = [:]
        var weatherDone = false, mlDone = false, searchDone = false, packingDone = false
        var detailsDone = 0

        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userMessage]
        ]

        var didRetryJSON = false
        var iterations = 0

        while iterations < maxIterations {
            iterations += 1

            let choice = nextToolChoice(weatherDone: weatherDone, mlDone: mlDone,
                                        searchDone: searchDone, detailsDone: detailsDone,
                                        packingDone: packingDone)
            let forcingFinal = (choice as? String) == "none"
            let response = try await callDeepSeek(messages: messages, toolChoice: choice,
                                                  tools: AgentTools.definitions)

            if !forcingFinal, !response.toolCalls.isEmpty {
                messages.append(assistantMessage(for: response))
                for toolCall in response.toolCalls {
                    let result = await executeTool(name: toolCall.name, arguments: toolCall.arguments)
                    messages.append(toolResultMessage(id: toolCall.id, content: result))
                    switch AgentTools.Name(rawValue: toolCall.name) {
                    case .getWeatherForecast:  weatherDone = true
                    case .runMLRecommendation: mlDone = true
                    case .searchAttractions:   searchDone = true
                    case .getAttractionDetail: detailsDone += 1
                    case .getPackingTips:      packingDone = true
                    case .none:                break
                    }
                }
                continue
            }

            agentStatus = "Building your itinerary..."
            do {
                return try parseItinerary(from: response.content)
            } catch {
                if !didRetryJSON {
                    didRetryJSON = true
                    messages.append(["role": "user",
                                     "content": "Return valid JSON only, no markdown, no explanation."])
                    continue
                }
                throw AgentError.malformedJSON
            }
        }

        throw AgentError.maxIterationsExceeded
    }

    /// Forces the next required tool in order; returns "none" to force the final answer.
    private func nextToolChoice(weatherDone: Bool, mlDone: Bool, searchDone: Bool,
                                detailsDone: Int, packingDone: Bool) -> Any {
        func force(_ name: AgentTools.Name) -> [String: Any] {
            ["type": "function", "function": ["name": name.rawValue]]
        }
        if !weatherDone { return force(.getWeatherForecast) }
        if !mlDone { return force(.runMLRecommendation) }
        if !searchDone { return force(.searchAttractions) }
        if detailsDone < targetDetailSlots { return force(.getAttractionDetail) }
        if !packingDone { return force(.getPackingTips) }
        return "none"
    }

    // MARK: - Multi-day trip generator

    private let tripSystemPrompt = """
    You are a travel planning assistant for TripIn. You build complete multi-day \
    itineraries using PRE-FETCHED weather data and a LIMITED set of tool calls.

    You will receive in the user message: city, startDate, numberOfDays, dailyBudget, \
    currency, and weatherByDay (an array of weather, one entry per day, ALREADY \
    FETCHED — never request weather).

    For EACH day, using its weatherByDay entry:
    1. Call run_ml_recommendation with that day's weather to get a category.
    2. Call search_attractions(category, city, limit=8). If you already searched that \
    exact category+city earlier, reuse those results — do not call it again.
    3. Select 3 to 4 attractions for that day, and you may add one meal stop \
    (type "meal") between them — aim for a full, varied day.
    4. Call get_attraction_detail ONLY for attractions not yet detailed, AND only while \
    you are under the detail-call limit you have been given. Once the limit is reached, \
    use the basic info already returned by search_attractions for the remaining places.
    5. Call get_packing_tips for that day's weather.

    Budget rules: the sum of estimatedCost in a day must not exceed dailyBudget (in the \
    given currency); reserve ~30% of dailyBudget for meals; if over budget, swap to a \
    cheaper or free attraction; prioritize free/low-cost attractions when the daily budget is tight.
    Variety rules: never repeat the same attraction title on consecutive days; rotate \
    categories across days (beach, outdoor, nature, cultural, indoor).
    Preference rules: STRICTLY respect the user's stated preferences/restrictions — e.g. \
    dietary (only suggest halal / vegetarian / kosher / etc. food when requested), pace \
    (avoid strenuous or tiring activities for a relaxed trip), accessibility, or interests. \
    If the budget is "no strict limit", keep costs sensible without forcing the cheapest options.

    Output ONLY valid JSON (no markdown, no explanation) matching:
    {"trip":{"city":"","startDate":"YYYY-MM-DD","numberOfDays":0,"dailyBudget":0,\
    "currency":"IDR","totalTripCost":""},"days":[{"dayNumber":0,"date":"YYYY-MM-DD",\
    "weather":{"condition":"","temperature":0,"uvIndex":0,"recommendation":""},\
    "slots":[{"time":"08:00","endTime":"10:00","type":"attraction","title":"",\
    "description":"","location":"","estimatedCost":"","tip":"","durationMinutes":0}],\
    "packingList":[""],"dayTotalCost":""}]}

    Before responding verify: days.length == numberOfDays; each dayTotalCost <= \
    dailyBudget; totalTripCost == sum of dayTotalCost; no consecutive-day attraction \
    repeats; valid JSON with no trailing commas.
    """

    /// Generates a multi-day Trip. Strategy 4: returns a <24h cached trip if one exists
    /// (zero API calls). Otherwise pre-fetches all weather (Strategy 1), runs the loop
    /// with the reduced tool set, auto-saves the result, and returns it.
    func generateTrip(city: String, startDate: String, numberOfDays: Int,
                      dailyBudget: Double, currency: String,
                      preferences: String = "", for userId: String) async throws -> Trip {
        let days = max(1, min(numberOfDays, 7))
        let prefs = preferences.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strategy 4 — local cache (skip when preferences are set, since those
        // aren't part of the cache key and would otherwise collide).
        if prefs.isEmpty,
           let cached = try? await FirestoreService.shared.fetchCachedTrip(
            city: city, startDate: startDate, numberOfDays: days,
            dailyBudget: dailyBudget, currency: currency, for: userId) {
            print("[Agent] cache hit — 0 API calls for \(days)-day \(city) trip")
            // Re-apply ML durations so a changed travel pace is reflected.
            return DurationEstimatorService.shared.enrich(trip: cached)
        }

        detailCallCount = 0
        detailCap = min(max(days * 2, 4), 8)   // detail a few per day; rest reuse search info
        seenAttractions = [:]

        // Strategy 1 — one weather call for all days.
        agentStatus = "Checking weather forecast..."
        let weatherByDay = try await WeatherService.shared.fetchMultiDayForecast(city: city, days: days)

        let budgetLine = dailyBudget > 0 ? "\(dailyBudget) \(currency) per day" : "no strict limit"
        let userMessage = """
        Plan a \(days)-day trip.
        city: \(city)
        startDate: \(startDate)
        numberOfDays: \(days)
        dailyBudget: \(budgetLine)
        currency: \(currency)
        preferences/restrictions (MUST respect): \(prefs.isEmpty ? "none" : prefs)
        weatherByDay (already fetched, do not request weather): \(weatherContext(weatherByDay, startDate: startDate))
        All costs are in \(currency); use \(currency) in every estimatedCost, dayTotalCost, and totalTripCost.
        """

        var messages: [[String: Any]] = [
            ["role": "system", "content": tripSystemPrompt],
            ["role": "user", "content": userMessage]
        ]

        let maxIter = min(days * 4 + 4, 20)
        var iterations = 0
        var toolCalls = 0
        var didRetryJSON = false

        while iterations < maxIter {
            iterations += 1
            let response = try await callDeepSeek(messages: messages, toolChoice: "auto",
                                                  tools: AgentTools.tripToolDefinitions)

            if response.finishReason == "tool_calls", !response.toolCalls.isEmpty {
                messages.append(assistantMessage(for: response))
                for toolCall in response.toolCalls {
                    toolCalls += 1
                    let result = await executeTool(name: toolCall.name, arguments: toolCall.arguments)
                    messages.append(toolResultMessage(id: toolCall.id, content: result))
                }
                continue
            }

            agentStatus = "Building your itinerary..."
            do {
                var trip = try parseTrip(from: response.content)
                trip = DurationEstimatorService.shared.enrich(trip: trip)   // ML-predicted durations
                trip = await DistanceService.shared.enrich(trip)           // bake in travel legs
                print("[Agent] \(days)-day trip built — \(toolCalls) tool calls, \(iterations) iterations, \(detailCallCount) detail calls")
                try? await FirestoreService.shared.saveTrip(trip, for: userId)  // populate cache
                return trip
            } catch {
                if !didRetryJSON {
                    didRetryJSON = true
                    messages.append(["role": "user",
                                     "content": "Return valid JSON only, no markdown, matching the required shape."])
                    continue
                }
                throw AgentError.malformedJSON
            }
        }

        print("[Agent] hit maxIterations (\(maxIter)) with \(toolCalls) tool calls")
        throw AgentError.maxIterationsExceeded
    }

    private func weatherContext(_ weatherByDay: [WeatherData], startDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.date(from: startDate)
        var array: [[String: Any]] = []
        for (index, w) in weatherByDay.enumerated() {
            let dateString: String
            if let start, let d = Calendar.current.date(byAdding: .day, value: index, to: start) {
                dateString = formatter.string(from: d)
            } else {
                dateString = startDate
            }
            array.append([
                "dayNumber": index + 1, "date": dateString,
                "condition": w.condition, "temperature": w.temperature, "uvIndex": w.uvIndex,
                "humidity": w.humidity, "windSpeed": w.windSpeed, "precipitation": w.precipitation,
                "season": w.season, "location": w.location
            ])
        }
        guard let data = try? JSONSerialization.data(withJSONObject: array),
              let string = String(data: data, encoding: .utf8) else { return "[]" }
        return string
    }

    private func parseTrip(from raw: String) throws -> Trip {
        let jsonText = extractJSON(from: raw)
        guard let data = jsonText.data(using: .utf8) else { throw AgentError.malformedJSON }

        let decoded: AgentTrip
        do {
            decoded = try JSONDecoder().decode(AgentTrip.self, from: data)
        } catch {
            throw AgentError.malformedJSON
        }

        let days = decoded.days.map { day in
            ItineraryDay(
                id: UUID().uuidString, date: day.date, city: decoded.trip.city,
                weather: day.weather, slots: day.slots, packingList: day.packingList,
                totalEstimatedCost: day.dayTotalCost, createdAt: Date()
            )
        }
        return Trip(
            id: UUID().uuidString, city: decoded.trip.city, startDate: decoded.trip.startDate,
            numberOfDays: decoded.trip.numberOfDays, dailyBudget: decoded.trip.dailyBudget,
            currency: decoded.trip.currency, totalTripCost: decoded.trip.totalTripCost,
            days: days, createdAt: Date()
        )
    }

    // MARK: - Single-shot AI tips (no tools)

    /// One DeepSeek call returning what to wear / bring / best time to visit.
    func attractionTips(for attraction: Attraction) async throws -> AttractionTips {
        let prompt = """
        Give concise travel tips for visiting "\(attraction.name)" (\(attraction.category)) \
        at \(attraction.address).
        Return ONLY a JSON object, no markdown:
        {"wear":"...","bring":"...","bestTime":"..."}
        Each value is one short, practical sentence.
        """
        let content = try await simpleCompletion(messages: [["role": "user", "content": prompt]])
        let json = extractJSON(from: content)
        guard let data = json.data(using: .utf8),
              let tips = try? JSONDecoder().decode(AttractionTips.self, from: data) else {
            throw AgentError.malformedJSON
        }
        return tips
    }

    private func simpleCompletion(messages: [[String: Any]]) async throws -> String {
        guard let url = URL(string: baseURL) else { throw AgentError.network }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.deepSeekKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["model": model, "messages": messages])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AgentError.network
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AgentError.network
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw AgentError.malformedJSON }
        return content
    }

    // MARK: - Multi-agent support

    /// One role-scoped completion (no tools) — used by the collaborating agents.
    func runRole(system: String, user: String) async throws -> String {
        try await simpleCompletion(messages: [
            ["role": "system", "content": system],
            ["role": "user", "content": user]
        ])
    }

    /// Parses a final {trip,days} JSON string into a Trip (reuses the agent parser).
    func parseTripJSON(_ raw: String) throws -> Trip { try parseTrip(from: raw) }

    /// Isolates the first balanced JSON object from a model reply.
    func extractJSONObject(_ raw: String) -> String { extractJSON(from: raw) }

    // MARK: - DeepSeek request

    private func callDeepSeek(messages: [[String: Any]], toolChoice: Any,
                             tools: [[String: Any]]) async throws -> DeepSeekResponse {
        guard let url = URL(string: baseURL) else { throw AgentError.network }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.deepSeekKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "tools": tools,
            "tool_choice": toolChoice
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AgentError.network
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AgentError.network
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let choice = choices.first,
            let message = choice["message"] as? [String: Any]
        else {
            throw AgentError.malformedJSON
        }

        let finishReason = choice["finish_reason"] as? String ?? "stop"
        let content = message["content"] as? String ?? ""

        let toolCalls: [DeepSeekToolCall] = (message["tool_calls"] as? [[String: Any]] ?? []).compactMap { raw in
            guard
                let id = raw["id"] as? String,
                let fn = raw["function"] as? [String: Any],
                let name = fn["name"] as? String
            else { return nil }
            let argsString = fn["arguments"] as? String ?? "{}"
            let args = (try? JSONSerialization.jsonObject(with: Data(argsString.utf8))) as? [String: Any] ?? [:]
            return DeepSeekToolCall(id: id, name: name, arguments: args)
        }

        return DeepSeekResponse(finishReason: finishReason, content: content, toolCalls: toolCalls)
    }

    private func assistantMessage(for response: DeepSeekResponse) -> [String: Any] {
        let toolCalls: [[String: Any]] = response.toolCalls.map { tc in
            let argsString = (try? JSONSerialization.data(withJSONObject: tc.arguments))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return [
                "id": tc.id,
                "type": "function",
                "function": ["name": tc.name, "arguments": argsString]
            ]
        }
        return [
            "role": "assistant",
            "content": response.content,
            "tool_calls": toolCalls
        ]
    }

    private func toolResultMessage(id: String, content: String) -> [String: Any] {
        ["role": "tool", "tool_call_id": id, "content": content]
    }

    // MARK: - Tool execution

    private func executeTool(name: String, arguments: [String: Any]) async -> String {
        switch AgentTools.Name(rawValue: name) {
        case .getWeatherForecast:
            agentStatus = "Checking weather forecast..."
            return await runWeather(arguments)

        case .runMLRecommendation:
            agentStatus = "Running ML recommendation..."
            return runML(arguments)

        case .searchAttractions:
            agentStatus = "Searching attractions..."
            return await runSearch(arguments)

        case .getAttractionDetail:
            agentStatus = "Getting attraction details..."
            return await runDetail(arguments)

        case .getPackingTips:
            agentStatus = "Building your itinerary..."
            return runPackingTips(arguments)

        case .none:
            return jsonString(["error": "unknown tool \(name)"])
        }
    }

    private func runWeather(_ args: [String: Any]) async -> String {
        let city = args["city"] as? String ?? ""
        let date = args["date"] as? String ?? ""
        do {
            let w = try await WeatherService.shared.fetchForecast(city: city, date: date)
            return jsonString([
                "city": w.city, "temperature": w.temperature, "humidity": w.humidity,
                "windSpeed": w.windSpeed, "precipitation": w.precipitation, "uvIndex": w.uvIndex,
                "condition": w.condition, "season": w.season, "location": w.location
            ])
        } catch {
            return jsonString(["error": (error as? LocalizedError)?.errorDescription ?? "weather unavailable"])
        }
    }

    private func runML(_ args: [String: Any]) -> String {
        let weather = WeatherData(
            city: args["city"] as? String ?? "",
            temperature: doubleValue(args["temperature"]),
            humidity: doubleValue(args["humidity"]),
            windSpeed: doubleValue(args["windSpeed"]),
            precipitation: doubleValue(args["precipitation"]),
            uvIndex: Int(doubleValue(args["uvIndex"])),
            condition: args["condition"] as? String ?? "Cloudy",
            season: args["season"] as? String ?? "Summer",
            location: args["location"] as? String ?? "inland"
        )
        let category = MLRecommender.shared.predict(weather: weather)
        return jsonString(["category": category])
    }

    private func runSearch(_ args: [String: Any]) async -> String {
        let category = args["category"] as? String ?? "outdoor"
        let city = args["city"] as? String ?? ""
        let limit = Int(doubleValue(args["limit"])) == 0 ? 5 : Int(doubleValue(args["limit"]))
        do {
            let results = try await PlacesService.shared.searchAttractions(category: category, city: city, limit: limit)
            for a in results { seenAttractions[a.id] = a }   // for detail-cap reuse
            let mapped = results.map { a -> [String: Any] in
                ["placeId": a.id, "name": a.name, "category": a.category,
                 "address": a.address, "rating": a.rating, "estimatedCost": a.estimatedCost]
            }
            return jsonString(["results": mapped])
        } catch {
            return jsonString(["error": (error as? LocalizedError)?.errorDescription ?? "search failed"])
        }
    }

    private func runDetail(_ args: [String: Any]) async -> String {
        let placeId = args["placeId"] as? String ?? ""

        // Strategy 3: once the global cap is hit, reuse basic search info — no API call.
        guard detailCallCount < detailCap else {
            if let a = seenAttractions[placeId] {
                return jsonString([
                    "name": a.name, "category": a.category, "description": a.description,
                    "address": a.address, "estimatedCost": a.estimatedCost, "rating": a.rating,
                    "latitude": a.latitude, "longitude": a.longitude,
                    "note": "detail limit (\(detailCap)) reached; using search info"
                ])
            }
            return jsonString(["error": "detail limit (\(detailCap)) reached; use search info"])
        }
        detailCallCount += 1
        do {
            let a = try await PlacesService.shared.attractionDetail(placeId: placeId)
            return jsonString([
                "name": a.name, "category": a.category, "description": a.description,
                "address": a.address, "estimatedCost": a.estimatedCost,
                "openingHours": a.openingHours, "rating": a.rating,
                "latitude": a.latitude, "longitude": a.longitude
            ])
        } catch {
            return jsonString(["error": (error as? LocalizedError)?.errorDescription ?? "detail failed"])
        }
    }

    private func runPackingTips(_ args: [String: Any]) -> String {
        let condition = args["condition"] as? String ?? "Cloudy"
        let temp = doubleValue(args["temperature"])

        var list: [String] = ["comfortable walking shoes", "phone & charger", "reusable water bottle"]
        switch condition {
        case "Rainy": list += ["umbrella", "light raincoat", "waterproof bag"]
        case "Sunny": list += ["sunscreen", "sunglasses", "hat"]
        case "Snowy": list += ["warm jacket", "gloves", "beanie"]
        default:      list += ["light jacket"]
        }
        if temp >= 28 { list += ["light breathable clothing", "stay hydrated"] }
        if temp <= 10 { list += ["thermal layers"] }

        let tip: String
        if condition == "Rainy" { tip = "Plan indoor backups in case of heavy rain." }
        else if temp >= 28 { tip = "Start early to avoid midday heat." }
        else if temp <= 10 { tip = "Dress in layers you can remove indoors." }
        else { tip = "Great weather for exploring on foot." }

        return jsonString(["packingList": list, "tip": tip])
    }

    // MARK: - Parsing

    private func parseItinerary(from raw: String) throws -> ItineraryDay {
        let jsonText = extractJSON(from: raw)
        guard let data = jsonText.data(using: .utf8) else { throw AgentError.malformedJSON }

        let decoded: AgentItinerary
        do {
            decoded = try JSONDecoder().decode(AgentItinerary.self, from: data)
        } catch {
            throw AgentError.malformedJSON
        }

        return ItineraryDay(
            id: UUID().uuidString,
            date: decoded.date,
            city: decoded.city,
            weather: decoded.weather,
            slots: decoded.slots,
            packingList: decoded.packingList,
            totalEstimatedCost: decoded.totalEstimatedCost,
            createdAt: Date()
        )
    }

    /// Strips markdown fences and returns the first complete, balanced JSON object,
    /// ignoring any prose the model adds before or after it.
    private func extractJSON(from raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "```json", with: "")
                   .replacingOccurrences(of: "```", with: "")
        guard let start = text.firstIndex(of: "{") else { return text }

        var depth = 0
        var inString = false
        var escaped = false
        var index = start
        while index < text.endIndex {
            let ch = text[index]
            if inString {
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == "\"" { inString = false }
            } else {
                if ch == "\"" { inString = true }
                else if ch == "{" { depth += 1 }
                else if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(text[start...index]) }
                }
            }
            index = text.index(after: index)
        }
        return String(text[start...])
    }

    // MARK: - Helpers

    private func doubleValue(_ any: Any?) -> Double {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String { return Double(s) ?? 0 }
        return 0
    }

    private func jsonString(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}

// MARK: - DeepSeek decoded shapes

struct DeepSeekResponse {
    let finishReason: String          // "stop" | "tool_calls"
    let content: String
    let toolCalls: [DeepSeekToolCall]
}

struct DeepSeekToolCall {
    let id: String
    let name: String
    let arguments: [String: Any]
}

/// Result of the single-shot AI tips prompt.
struct AttractionTips: Decodable {
    let wear: String
    let bring: String
    let bestTime: String
}

/// Decoded shape of the final itinerary JSON (id/createdAt are added locally).
private struct AgentItinerary: Decodable {
    let date: String
    let city: String
    let weather: WeatherSummary
    let slots: [TimeSlot]
    let packingList: [String]
    let totalEstimatedCost: String
}

/// Decoded shape of the multi-day trip JSON from the generator.
private struct AgentTrip: Decodable {
    struct Meta: Decodable {
        let city: String
        let startDate: String
        let numberOfDays: Int
        let dailyBudget: Double
        let currency: String
        let totalTripCost: String
    }
    struct Day: Decodable {
        let dayNumber: Int
        let date: String
        let weather: WeatherSummary
        let slots: [TimeSlot]
        let packingList: [String]
        let dayTotalCost: String
    }
    let trip: Meta
    let days: [Day]
}
