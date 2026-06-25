import SwiftUI
import UIKit

struct NearMeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = NearMeViewModel()

    @State private var showAgent = false
    @State private var selectedAttraction: Attraction?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        content
                    }
                    .padding(Theme.padding)
                    .padding(.bottom, 90)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Near Me")
            .task {
                if viewModel.detectedCity.isEmpty { await viewModel.loadNearbyRecommendations() }
            }
            .sheet(item: $selectedAttraction) { attraction in
                NavigationStack { AttractionDetailView(attraction: attraction) }
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showAgent) {
                NavigationStack { AgentChatView(prefillCity: viewModel.detectedCity) }
                    .environmentObject(authViewModel)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingState
        } else if isDenied {
            deniedState
        } else if !viewModel.errorMessage.isEmpty {
            errorState
        } else {
            resultsState
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.coral)
            Text("Detecting your location…").foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private var deniedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash").font(.largeTitle).foregroundColor(Theme.textSecondary)
            Text(viewModel.errorMessage.isEmpty ? "Location access denied." : viewModel.errorMessage)
                .multilineTextAlignment(.center).foregroundColor(Theme.textSecondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered).tint(Theme.coral)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(Theme.textSecondary)
            Text(viewModel.errorMessage)
                .multilineTextAlignment(.center).foregroundColor(Theme.textSecondary)
            Button("Try Again") { Task { await viewModel.loadNearbyRecommendations() } }
                .buttonStyle(.bordered).tint(Theme.coral)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private var resultsState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("✅ You're in: \(viewModel.detectedCity)")
                .font(.title3.bold()).foregroundColor(Theme.navy)

            Text("Recommended for you today")
                .font(.headline).foregroundColor(Theme.textSecondary)

            if viewModel.attractions.isEmpty {
                Text("No recommendations found nearby.")
                    .foregroundColor(Theme.textSecondary)
            } else {
                ForEach(viewModel.attractions) { attraction in
                    Button { selectedAttraction = attraction } label: {
                        AttractionCardView(attraction: attraction)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button { showAgent = true } label: {
                Label("Plan a full day here", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
            .disabled(viewModel.detectedCity.isEmpty)
        }
    }

    private var isDenied: Bool {
        if case .denied = viewModel.status { return true }
        return false
    }
}
