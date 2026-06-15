import Foundation
import Combine

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

@MainActor
final class AgentViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isThinking: Bool = false
    @Published var statusText: String = ""
    @Published var resultItinerary: ItineraryDay?
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Mirror the agent's live progress into the chat's typing indicator.
        AgentService.shared.$agentStatus
            .sink { [weak self] status in self?.statusText = status }
            .store(in: &cancellables)
    }

    func seedGreetingIfNeeded() {
        guard messages.isEmpty else { return }
        messages.append(ChatMessage(
            role: .assistant,
            text: "Hi! Tell me where and when you'd like to travel — e.g. \"Plan my day in Bali on 2026-07-15\"."
        ))
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }

        messages.append(ChatMessage(role: .user, text: text))
        inputText = ""
        errorMessage = nil
        resultItinerary = nil
        isThinking = true
        statusText = "Thinking…"

        do {
            let itinerary = try await AgentService.shared.planTrip(userMessage: text)
            resultItinerary = itinerary
            messages.append(ChatMessage(role: .assistant, text: summary(for: itinerary)))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "Could not build itinerary. Please try again."
            messages.append(ChatMessage(role: .assistant, text: message))
            errorMessage = message
        }

        isThinking = false
        statusText = ""
    }

    private func summary(for itinerary: ItineraryDay) -> String {
        "Here's your day in \(itinerary.city) on \(itinerary.date)! "
        + "I planned \(itinerary.slots.count) stops based on \(itinerary.weather.condition.lowercased()) weather. "
        + "Tap below to view the full itinerary."
    }
}
