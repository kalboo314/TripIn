import SwiftUI

/// A searchable place picker presented as a sheet. Calls `onSelect` with the chosen attraction.
struct PlacePickerView: View {
    let city: String
    let onSelect: (Attraction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Attraction] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField("Search places (e.g. cafe, museum)", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await search() } }
                    Button("Search") { Task { await search() } }
                        .tint(Theme.coral)
                }
                .padding()

                Group {
                    if isLoading {
                        ProgressView("Searching…").frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error {
                        InfoStateView(icon: "exclamationmark.triangle", title: error, tint: Theme.coral)
                    } else if results.isEmpty {
                        InfoStateView(icon: "magnifyingglass",
                                      title: "Search for a place to add",
                                      message: "Try \"museum\", \"park\" or \"restaurant\" in \(city).")
                    } else {
                        List(results) { attraction in
                            Button { onSelect(attraction); dismiss() } label: { row(attraction) }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Pick a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ attraction: Attraction) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: attraction.photoUrl)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.systemGray5)
            }
            .frame(width: 56, height: 56)
            .clipped()
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(attraction.name).font(.subheadline.bold()).foregroundColor(Theme.navy)
                Text(attraction.address).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Text(attraction.estimatedCost).font(.caption).foregroundColor(.secondary)
        }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            results = try await PlacesService.shared.searchAttractions(
                category: trimmed.isEmpty ? "tourist attraction" : trimmed,
                city: city, limit: 12)
        } catch let err {
            self.error = (err as? LocalizedError)?.errorDescription ?? "Search failed. Please try again."
            results = []
        }
    }
}
