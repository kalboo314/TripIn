import Foundation

/// App-level user model. Named `AppUser` to avoid colliding with `FirebaseAuth.User`.
struct AppUser: Codable, Identifiable {
    let id: String          // Firebase UID
    let email: String
    let displayName: String
}
