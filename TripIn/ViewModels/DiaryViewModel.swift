import Foundation
import UIKit

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var entries: [DiaryEntry] = []
    @Published var isLoading: Bool = false
    @Published var isUploading: Bool = false
    @Published var errorMessage: String?

    func load(for userId: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await FirestoreService.shared.fetchDiaryEntries(for: userId)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not load your diary. Please try again."
        }
    }

    /// Compresses + uploads the photo, then saves the entry (with the ML scene tag).
    func addEntry(image: UIImage, caption: String, place: String,
                  sceneTag: String, for userId: String) async -> Bool {
        errorMessage = nil
        isUploading = true
        defer { isUploading = false }

        // Keep the JPEG small so the base64 string fits Firestore's 1 MB doc limit.
        guard let data = image.jpegDataUnder(maxBytes: 550_000) else {
            errorMessage = "Could not process that photo."
            return false
        }
        let id = UUID().uuidString
        do {
            let entry = DiaryEntry(
                id: id, imageData: data.base64EncodedString(), caption: caption,
                place: place.trimmingCharacters(in: .whitespaces),
                sceneTag: sceneTag.isEmpty ? "outdoor" : sceneTag,
                createdAt: Date())
            try await FirestoreService.shared.saveDiaryEntry(entry, for: userId)
            entries.insert(entry, at: 0)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not save your diary entry. Please try again."
            return false
        }
    }

    func delete(_ entry: DiaryEntry, for userId: String) async {
        do {
            try await FirestoreService.shared.deleteDiaryEntry(id: entry.id, for: userId)
            entries.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not delete that entry. Please try again."
        }
    }
}
