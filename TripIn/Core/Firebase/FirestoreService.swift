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

    /// Collection path: users/{userId}/diary
    private func diaryRef(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("diary")
    }

    // MARK: - Travel diary

    func saveDiaryEntry(_ entry: DiaryEntry, for userId: String) async throws {
        do {
            try diaryRef(userId).document(entry.id).setData(from: entry)
        } catch {
            throw FirestoreError.write
        }
    }

    func fetchDiaryEntries(for userId: String) async throws -> [DiaryEntry] {
        do {
            let snapshot = try await diaryRef(userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: DiaryEntry.self) }
        } catch {
            throw FirestoreError.read
        }
    }

    func deleteDiaryEntry(id: String, for userId: String) async throws {
        do {
            try await diaryRef(userId).document(id).delete()
        } catch {
            throw FirestoreError.write
        }
    }

    func saveTrip(_ trip: Trip, for userId: String) async throws {
        do {
            try tripsRef(userId).document(trip.id).setData(from: trip)
        } catch {
            throw FirestoreError.write
        }
    }

    func fetchTrips(for userId: String) async throws -> [Trip] {
        do {
            let snapshot = try await tripsRef(userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Trip.self) }
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

    /// Strategy 4: returns a cached trip matching city+startDate+numberOfDays+dailyBudget
    /// created within the last 24h, or nil. Uses equality filters only (no composite
    /// index needed); recency is filtered client-side.
    func fetchCachedTrip(city: String, startDate: String, numberOfDays: Int,
                         dailyBudget: Double, currency: String, for userId: String) async throws -> Trip? {
        do {
            let snapshot = try await tripsRef(userId)
                .whereField("city", isEqualTo: city)
                .whereField("startDate", isEqualTo: startDate)
                .whereField("numberOfDays", isEqualTo: numberOfDays)
                .whereField("dailyBudget", isEqualTo: dailyBudget)
                .whereField("currency", isEqualTo: currency)
                .getDocuments()
            let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
            return snapshot.documents
                .compactMap { try? $0.data(as: Trip.self) }
                .filter { $0.createdAt > cutoff }
                .sorted { $0.createdAt > $1.createdAt }
                .first
        } catch {
            throw FirestoreError.read
        }
    }
}
