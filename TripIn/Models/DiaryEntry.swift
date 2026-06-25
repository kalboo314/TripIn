import Foundation

/// A single travel-diary post: a photo plus caption/place and an ML-detected scene tag.
struct DiaryEntry: Codable, Identifiable {
    let id: String
    let imageData: String    // base64 JPEG (kept small to fit Firestore's 1 MB doc limit)
    let caption: String
    let place: String        // optional city/place ("")
    let sceneTag: String     // ML scene category: beach / nature / cultural / outdoor
    let createdAt: Date
}
