import SwiftUI

struct AgentChatView: View {
    var prefillCity: String? = nil

    @StateObject private var viewModel = AgentViewModel()
    @State private var showItinerary = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                bubble(message).id(message.id)
                            }
                            if viewModel.isThinking {
                                typingIndicator.id("typing")
                            }
                            if viewModel.resultTrip != nil {
                                viewItineraryButton.id("result")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in scrollToBottom(proxy) }
                    .onChange(of: viewModel.isThinking) { _ in scrollToBottom(proxy) }
                }

                inputBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Travel Agent")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showItinerary) {
                if let trip = viewModel.resultTrip {
                    ItineraryView(trip: trip)
                }
            }
            .onAppear {
                viewModel.seedGreetingIfNeeded()
                if let city = prefillCity, !city.isEmpty, viewModel.inputText.isEmpty {
                    viewModel.inputText = "Plan my day in \(city)"
                }
            }
        }
    }

    // MARK: - Pieces

    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .padding(12)
                .background(message.role == .user ? Theme.coral : Theme.card)
                .foregroundColor(message.role == .user ? .white : Theme.navy)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.8)
                Text(viewModel.statusText.isEmpty ? "Thinking…" : viewModel.statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Theme.card)
            .cornerRadius(16)
            Spacer(minLength: 40)
        }
    }

    private var viewItineraryButton: some View {
        Button { showItinerary = true } label: {
            Label("View Full Itinerary", systemImage: "map.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, 4)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Plan my day in…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(viewModel.isThinking)

            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title)
            }
            .tint(Theme.coral)
            .disabled(viewModel.isThinking
                      || viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(Theme.card)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if viewModel.resultTrip != nil {
                proxy.scrollTo("result", anchor: .bottom)
            } else if viewModel.isThinking {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

struct AgentChatView_Previews: PreviewProvider {
    static var previews: some View {
        AgentChatView()
    }
}
