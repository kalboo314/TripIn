import Foundation

struct Config {
    private static let plist: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any]
        else { fatalError("APIKeys.plist not found.") }
        return dict
    }()

    static var weatherKey: String { plist["OpenWeatherMapKey"] as? String ?? "" }
    static var placesKey: String  { plist["GooglePlacesKey"]   as? String ?? "" }
    static var deepSeekKey: String { plist["DeepSeekKey"]      as? String ?? "" }
}
