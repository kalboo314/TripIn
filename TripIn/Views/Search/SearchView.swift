import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        inputCard

                        if let weather = viewModel.weather {
                            weatherChip(weather)
                        }

                        content
                    }
                    .padding(.horizontal, Theme.padding)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Plan a Day")
        }
    }

    // MARK: - Input

    private var inputCard: some View {
        VStack(spacing: 12) {
            AuthTextField(placeholder: "City", text: $viewModel.city,
                          systemImage: "mappin.and.ellipse")

            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(Theme.coral)

            Button {
                Task { await viewModel.planMyDay() }
            } label: {
                if viewModel.isLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Plan My Day").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.city.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
        }
        .padding(Theme.padding)
        .background(Theme.card)
        .cornerRadius(Theme.cardRadius)
        .padding(.top, Theme.padding)
    }

    private func weatherChip(_ weather: WeatherData) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: weather.condition))
                .font(.title3)
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(weather.condition) · \(Int(weather.temperature))°C")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                if let category = viewModel.recommendedCategory {
                    Text("Recommended: \(category.capitalized)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            Spacer()
        }
        .padding(Theme.padding)
        .background(Theme.coral.opacity(0.85))
        .cornerRadius(Theme.cardRadius)
    }

    // MARK: - Results / states

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage {
            stateView(icon: "exclamationmark.triangle", title: error)
        } else if viewModel.isLoading {
            ProgressView("Finding the best spots…")
                .tint(.white)
                .foregroundColor(.white)
                .padding(.top, 40)
        } else if viewModel.hasSearched && viewModel.results.isEmpty {
            stateView(icon: "magnifyingglass", title: "No attractions found.\nTry another city or date.")
        } else if !viewModel.hasSearched {
            stateView(icon: "map", title: "Enter a city and tap Plan My Day.")
        } else {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.results) { attraction in
                    NavigationLink {
                        AttractionDetailView(attraction: attraction)
                    } label: {
                        AttractionCardView(attraction: attraction, onAdd: {
                            // Wired to itinerary saving in a later step.
                        })
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func stateView(icon: String, title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.6))
            Text(title)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    private func icon(for condition: String) -> String {
        switch condition {
        case "Sunny":  return "sun.max.fill"
        case "Rainy":  return "cloud.rain.fill"
        case "Snowy":  return "snowflake"
        default:        return "cloud.fill"
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}
