import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = SearchViewModel()
    @State private var planMode: PlanMode = .auto
    @State private var showAgent = false
    @State private var detailAttraction: Attraction?

    private let currencies = ["IDR", "USD", "EUR", "GBP", "SGD", "MYR", "THB", "JPY", "CNY",
                              "AUD", "NZD", "KRW", "INR", "HKD", "AED", "VND", "PHP", "CAD", "CHF"]

    enum PlanMode { case manual, auto }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        aiBanner
                        inputCard

                        if planMode == .manual {
                            if let weather = viewModel.weather { weatherChip(weather) }
                            if !viewModel.draft.isEmpty { buildBar }
                            content
                        }
                    }
                    .padding(.horizontal, Theme.padding)
                    .padding(.bottom, 90)
                }
            }
            .navigationTitle("Plan a Trip")
            .onChange(of: viewModel.city) { _ in viewModel.autoDetectCurrency() }
            .sheet(item: $viewModel.generatedTrip) { trip in
                NavigationStack { ItineraryView(trip: trip) }
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showAgent) {
                AgentChatView().environmentObject(authViewModel)
            }
            .sheet(item: $detailAttraction) { attraction in
                NavigationStack {
                    AttractionDetailView(
                        attraction: attraction,
                        isInItinerary: viewModel.inDraft(attraction),
                        onAddToItinerary: { _ in viewModel.toggleDraft(attraction) })
                }
                .environmentObject(authViewModel)
            }
        }
    }

    // MARK: - AI chat entry

    private var aiBanner: some View {
        Button { showAgent = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3).foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chat with AI").font(.subheadline.bold()).foregroundColor(.white)
                    Text("Plan conversationally instead").font(.caption).foregroundColor(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.9))
            }
            .padding(Theme.padding)
            .background(Theme.coralGradient)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .shadow(color: Theme.coral.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .padding(.top, Theme.padding)
    }

    // MARK: - Input

    private var inputCard: some View {
        VStack(spacing: 14) {
            AuthTextField(placeholder: "City", text: $viewModel.city, systemImage: "mappin.and.ellipse")

            datesSection
            budgetSection

            Picker("Mode", selection: $planMode) {
                Text("Manual").tag(PlanMode.manual)
                Text("Auto").tag(PlanMode.auto)
            }
            .pickerStyle(.segmented)

            if planMode == .auto {
                TextField("Preferences (optional) — e.g. halal food, relaxed pace",
                          text: $viewModel.preferences, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
            }

            primaryButton

            if let error = viewModel.generateError {
                Text(error).font(.footnote).foregroundColor(.red)
            }
        }
        .padding(Theme.padding)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        .padding(.top, 4)
    }

    private var datesSection: some View {
        VStack(spacing: 8) {
            DatePicker("From", selection: $viewModel.startDate, displayedComponents: .date)
            DatePicker("To", selection: $viewModel.endDate,
                       in: viewModel.startDate..., displayedComponents: .date)
            HStack {
                Text("\(viewModel.numberOfDays) day\(viewModel.numberOfDays > 1 ? "s" : "")")
                    .font(.caption).foregroundColor(Theme.textSecondary)
                Spacer()
            }
        }
        .tint(Theme.coral)
    }

    private var budgetSection: some View {
        VStack(spacing: 10) {
            Toggle("Set a daily budget", isOn: $viewModel.budgetEnabled).tint(Theme.coral)
            if viewModel.budgetEnabled {
                HStack {
                    Picker("Currency", selection: $viewModel.currency) {
                        ForEach(currencies, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu).tint(Theme.coral)
                    Spacer()
                    TextField("200000", value: $viewModel.dailyBudget, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var primaryButton: some View {
        Button {
            if planMode == .manual {
                Task { await viewModel.planMyDay() }
            } else if let uid = authViewModel.currentUser?.id {
                Task { await viewModel.autoPlan(for: uid) }
            }
        } label: {
            if viewModel.isLoading || (planMode == .auto && viewModel.isGenerating) {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text(planMode == .auto
                         ? (viewModel.generationStage.isEmpty ? "Planning…" : viewModel.generationStage)
                         : "Searching…")
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(primaryTitle).frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(viewModel.city.trimmingCharacters(in: .whitespaces).isEmpty
                  || viewModel.isLoading || viewModel.isGenerating)
    }

    private var primaryTitle: String {
        if planMode == .manual { return "Find Places to Pick" }
        return viewModel.numberOfDays > 1
            ? "Auto-Plan \(viewModel.numberOfDays)-Day Trip"
            : "Auto-Plan My Trip"
    }

    private func weatherChip(_ weather: WeatherData) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: weather.condition)).font(.title3).foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(weather.condition) · \(Int(weather.temperature))°C")
                    .font(.subheadline.bold()).foregroundColor(.white)
                if let category = viewModel.recommendedCategory {
                    Text("Recommended: \(category.capitalized)")
                        .font(.caption).foregroundColor(.white.opacity(0.9))
                }
            }
            Spacer()
        }
        .padding(Theme.padding)
        .background(Theme.coralGradient)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    // Prominent "build" action shown once places are picked (the floating tab bar
    // covers the screen bottom, so this lives inline in the flow instead).
    private var buildBar: some View {
        Button { Task { await viewModel.buildManual() } } label: {
            if viewModel.isGenerating {
                HStack(spacing: 8) { ProgressView().tint(.white); Text("Building…") }
                    .frame(maxWidth: .infinity)
            } else {
                Label("Review & Build \(viewModel.numberOfDays)-Day Itinerary (\(viewModel.draft.count))",
                      systemImage: "checklist")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    // MARK: - Manual results

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage {
            stateView(icon: "exclamationmark.triangle", title: error)
        } else if viewModel.isLoading {
            ProgressView("Finding the best spots…")
                .tint(Theme.coral).foregroundColor(Theme.textSecondary).padding(.top, 40)
        } else if viewModel.hasSearched && viewModel.results.isEmpty {
            stateView(icon: "magnifyingglass", title: "No attractions found.\nTry another city.")
        } else if !viewModel.hasSearched {
            stateView(icon: "hand.tap", title: "Tap “Find Places to Pick”, then add the spots you like.")
        } else {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.results) { attraction in
                    // The "Add" button keeps its own taps; tapping elsewhere on the
                    // card opens detail (no NavigationLink swallowing the button).
                    AttractionCardView(
                        attraction: attraction,
                        isAdded: viewModel.inDraft(attraction),
                        onAdd: { viewModel.toggleDraft(attraction) })
                        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                        .onTapGesture { detailAttraction = attraction }
                }
            }
        }
    }

    private func stateView(icon: String, title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundColor(Theme.textSecondary)
            Text(title).multilineTextAlignment(.center).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func icon(for condition: String) -> String {
        switch condition {
        case "Sunny": return "sun.max.fill"
        case "Rainy": return "cloud.rain.fill"
        case "Snowy": return "snowflake"
        default:       return "cloud.fill"
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView().environmentObject(AuthViewModel())
    }
}
