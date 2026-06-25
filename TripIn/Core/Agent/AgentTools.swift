import Foundation

/// OpenAI-compatible tool (function) schemas sent to DeepSeek.
enum AgentTools {

    /// Names used in both the schema and the executor switch.
    enum Name: String {
        case getWeatherForecast  = "get_weather_forecast"
        case searchAttractions   = "search_attractions"
        case getAttractionDetail = "get_attraction_detail"
        case runMLRecommendation = "run_ml_recommendation"
        case getPackingTips      = "get_packing_tips"
    }

    /// Full `tools` array for the chat completions request body.
    static var definitions: [[String: Any]] {
        [
            function(
                name: .getWeatherForecast,
                description: "Get the weather forecast for a city on a specific date. Call this first.",
                properties: [
                    "city": ["type": "string", "description": "City name, e.g. \"Bali\"."],
                    "date": ["type": "string", "description": "Date in yyyy-MM-dd format."]
                ],
                required: ["city", "date"]
            ),
            function(
                name: .runMLRecommendation,
                description: "Run the on-device ML model to recommend an attraction category from the weather. Pass the weather values returned by get_weather_forecast.",
                properties: [
                    "temperature":   ["type": "number"],
                    "humidity":      ["type": "number"],
                    "windSpeed":     ["type": "number"],
                    "precipitation": ["type": "number"],
                    "uvIndex":       ["type": "integer"],
                    "condition":     ["type": "string", "description": "Sunny, Cloudy, Rainy or Snowy."],
                    "season":        ["type": "string"],
                    "location":      ["type": "string", "description": "coastal, inland or mountain."]
                ],
                required: ["temperature", "condition", "season", "location"]
            ),
            function(
                name: .searchAttractions,
                description: "Search for attractions of a given category in a city.",
                properties: [
                    "category": ["type": "string", "description": "Attraction category from the ML recommendation."],
                    "city":     ["type": "string"],
                    "limit":    ["type": "integer", "description": "Max number of results (1-10)."]
                ],
                required: ["category", "city", "limit"]
            ),
            function(
                name: .getAttractionDetail,
                description: "Get detailed information about one attraction by its placeId. Call up to 4 times for different places.",
                properties: [
                    "placeId": ["type": "string", "description": "The placeId returned by search_attractions."]
                ],
                required: ["placeId"]
            ),
            function(
                name: .getPackingTips,
                description: "Get a packing list and travel tips for the given weather. Call this last.",
                properties: [
                    "condition":   ["type": "string"],
                    "temperature": ["type": "number"]
                ],
                required: ["condition", "temperature"]
            )
        ]
    }

    /// Tool set for the multi-day generator: weather is pre-fetched (Strategy 1),
    /// so get_weather_forecast is excluded.
    static var tripToolDefinitions: [[String: Any]] {
        definitions.filter { dict in
            guard let fn = dict["function"] as? [String: Any],
                  let name = fn["name"] as? String else { return false }
            return name != Name.getWeatherForecast.rawValue
        }
    }

    private static func function(name: Name,
                                 description: String,
                                 properties: [String: Any],
                                 required: [String]) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name.rawValue,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required
                ]
            ]
        ]
    }
}
