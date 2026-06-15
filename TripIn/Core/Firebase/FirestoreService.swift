import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

enum FirestoreError: LocalizedError {
    case encoding
    case decoding
    case write
    case read

    var errorDescription: String? {
        switch self {
        case .write: return "Could not save trip. Please try again."
        case .read:  return "Could not load your trips. Please try again."
        default:     return "Something went wrong. Please try again."
        }
    }
}

final class FirestoreService {
    static let shared = FirestoreService()
    private init() {}

    private let db = Firestore.firestore()

    /// Collection path: users/{userId}/trips
    private func tripsRef(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("trips")
    }

    func saveTrip(_ trip: ItineraryDay, for userId: String) async throws {
        do {
            try tripsRef(userId).document(trip.id).setData(from: trip)
        } catch {
            throw FirestoreError.write
        }
    }

    func fetchTrips(for userId: String) async throws -> [ItineraryDay] {
        do {
            let snapshot = try await tripsRef(userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: ItineraryDay.self) }
        } catch {
            throw FirestoreError.read
        }
    }

    func deleteTrip(tripId: String, for userId: String) async throws {
        do {
            try await tripsRef(userId).document(tripId).delete()
        } catch {
            throw FirestoreError.write
        }
    }
}
