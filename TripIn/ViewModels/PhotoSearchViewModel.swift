import Foundation
import UIKit

@MainActor
final class PhotoSearchViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var detectedScene: String = ""
    @Published var cityQuery: String = ""
    @Published var citysuggestions: [CitysuggestionModel] = []
    @Published var selectedCity: String = ""
    @Published var isClassifying: Bool = false
    @Published var isSearchingSuggestions: Bool = false
    @Published var errorMessage: String = ""

    private let sceneClassifier = SceneClassifierService()
    private let placesService = PlacesService.shared

    private var suggestionTask: Task<Void, Never>?
    private var isSelecting = false      // suppresses the onChange caused by selectCity

    // MARK: - Photo classification

    func classifySelectedImage(_ image: UIImage) async {
        selectedImage = image
        isClassifying = true
        defer { isClassifying = false }
        do {
            detectedScene = try await sceneClassifier.classify(image: image)
        } catch {
            // Per error rules: fail silently and still proceed with city search.
            detectedScene = "outdoor"
        }
    }

    // MARK: - City autocomplete (debounced)

    /// Call from the TextField's onChange. Debounces 400ms and skips < 2 chars.
    func onCityQueryChanged(_ query: String) {
        if isSelecting { isSelecting = false; return }
        selectedCity = ""
        suggestionTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { citysuggestions = []; return }

        suggestionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            await self?.fetchCitySuggestions(query: trimmed)
        }
    }

    func fetchCitySuggestions(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { citysuggestions = []; return }
        isSearchingSuggestions = true
        defer { isSearchingSuggestions = false }
        do {
            citysuggestions = try await placesService.fetchCitySuggestions(query: trimmed)
        } catch {
            citysuggestions = []   // no error UI for autocomplete, per rules
        }
    }

    func selectCity(_ suggestion: CitysuggestionModel) {
        isSelecting = true
        cityQuery = suggestion.cityName
        selectedCity = suggestion.cityName
        citysuggestions = []
    }

    func clearCity() {
        suggestionTask?.cancel()
        cityQuery = ""
        selectedCity = ""
        citysuggestions = []
    }

    // MARK: - Final trigger (reuses the existing search flow)

    func searchWithPhotoAndCity(searchViewModel: SearchViewModel) async {
        let category = detectedScene.isEmpty ? "outdoor" : detectedScene
        searchViewModel.city = selectedCity
        await searchViewModel.searchAttractions(category: category)
    }
}
