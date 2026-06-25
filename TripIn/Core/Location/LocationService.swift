import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var currentCity: String = ""
    @Published var locationStatus: LocationStatus = .idle
    @Published var errorMessage: String = ""

    enum LocationStatus {
        case idle
        case requesting
        case locating
        case reverseGeocoding
        case done
        case denied
        case error
    }

    private let locationManager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        // City-level accuracy is enough and uses less battery than Best.
    }

    func requestCurrentCity() async throws -> String {
        locationStatus = .requesting

        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            locationStatus = .denied
            throw LocationError.permissionDenied
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // The didChangeAuthorization delegate triggers requestLocation once granted.
        default:
            break
        }

        locationStatus = .locating
        let location = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CLLocation, Error>) in
            self.continuation = cont
            if locationManager.authorizationStatus == .authorizedWhenInUse ||
               locationManager.authorizationStatus == .authorizedAlways {
                locationManager.requestLocation()
            }
        }

        locationStatus = .reverseGeocoding
        let city = try await reverseGeocode(location: location)
        currentCity = city
        locationStatus = .done
        return city
    }

    private func reverseGeocode(location: CLLocation) async throws -> String {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first,
              let city = placemark.locality ?? placemark.administrativeArea
        else { throw LocationError.cityNotFound }
        return city
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        locationStatus = .error
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            continuation?.resume(throwing: LocationError.permissionDenied)
            continuation = nil
            locationStatus = .denied
        default:
            break
        }
    }

    enum LocationError: LocalizedError {
        case permissionDenied
        case cityNotFound

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Location access denied. Enable it in Settings to use this feature."
            case .cityNotFound:
                return "Could not determine your city. Please type it manually."
            }
        }
    }
}
