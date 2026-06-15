import Foundation
import CoreML

final class MLRecommender {
    static let shared = MLRecommender()

    /// Generated `TravelRecommender` class is produced by Xcode from the bundled
    /// .mlmodel. Loading is best-effort; failures fall back to "outdoor".
    private let model: TravelRecommender?

    private init() {
        self.model = try? TravelRecommender(configuration: MLModelConfiguration())
    }

    /// Predicts the best attraction category for the given weather.
    /// Returns "outdoor" if the model is unavailable or prediction fails.
    func predict(weather: WeatherData) -> String {
        guard let model = model else { return "outdoor" }

        let input = TravelRecommenderInput(
            Temperature: weather.temperature,
            Humidity: weather.humidity,
            WindSpeed: weather.windSpeed,
            Precipitation: weather.precipitation,
            UVIndex: Double(weather.uvIndex),
            WeatherType: weather.condition,
            Season: weather.season,
            Location: weather.location
        )

        guard let output = try? model.prediction(input: input) else { return "outdoor" }
        return output.attraction_category
    }
}
