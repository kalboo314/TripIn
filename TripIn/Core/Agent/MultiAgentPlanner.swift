import Foundation

// MARK: - Multi-agent travel planning system
//
// Instead of one monolithic agent, trip generation is a collaboration between
// three specialized agents, each with a distinct ROLE and SKILLS, handing their
// output to the next:
//
//   1. PlannerAgent  (Trip Architect)   — selects which attractions go on which day
//   2. BudgetAgent   (Budget Optimizer) — turns selections into costed, timed slots
//   3. CriticAgent   (Quality Reviewer) — validates & emits the final itinerary JSON
//
// The TripAgentOrchestrator gathers the shared context (weather, ML category,
// candidate places) and routes work between the agents.

protocol CollaboratingAgent {
    var role: String { get }
    var skills: [String] { get }
    func run(payload: String) async throws -> String
}

// MARK: - 1. Planner Agent

struct PlannerAgent: CollaboratingAgent {
    let role = "Trip Architect"
    let skills = ["day structuring", "theme & pace selection", "preference matching", "variety control"]

    func run(payload: String) async throws -> String {
        try await AgentService.shared.runRole(system: systemPrompt, user: payload)
    }

    private let systemPrompt = """
    You are the PLANNER AGENT (Trip Architect) in a multi-agent travel-planning system.
    From each day's candidate attractions, SELECT 3–4 for that day. Ensure variety,
    NEVER repeat the same attraction on consecutive days, and respect the user's stated
    preferences and pace. Use only titles that appear in that day's candidate list.
    Output ONLY JSON, no markdown:
    {"days":[{"dayNumber":1,"selected":["Exact Candidate Title","..."]}]}
    """
}

// MARK: - 2. Budget Agent

struct BudgetAgent: CollaboratingAgent {
    let role = "Budget Optimizer"
    let skills = ["cost estimation", "budget allocation", "meal planning", "swap-to-cheaper"]

    func run(payload: String) async throws -> String {
        try await AgentService.shared.runRole(system: systemPrompt, user: payload)
    }

    private let systemPrompt = """
    You are the BUDGET AGENT (Budget Optimizer) in a multi-agent travel-planning system.
    You receive CONTEXT (city, currency, dailyBudget, per-day candidates with cost) and the
    PLANNER's selected attractions per day. For EACH day build a time-ordered list of slots
    starting 09:00: each selected attraction as type "attraction", plus ONE mid-day meal stop
    (type "meal"). Assign a realistic estimatedCost in the given currency, keep each day's total
    within dailyBudget (reserve ~30% for the meal); prefer free/cheap options when tight. If
    dailyBudget is 0, treat it as no strict limit. Fill description, location (use the candidate's
    address), a short tip, and durationMinutes.
    Output ONLY JSON, no markdown:
    {"days":[{"dayNumber":1,"slots":[{"time":"09:00","endTime":"11:00","type":"attraction",
    "title":"","description":"","location":"","estimatedCost":"","tip":"","durationMinutes":120}],
    "dayTotalCost":""}]}
    """
}

// MARK: - 3. Critic Agent

struct CriticAgent: CollaboratingAgent {
    let role = "Quality Reviewer"
    let skills = ["validation", "pacing check", "consistency", "final formatting"]

    func run(payload: String) async throws -> String {
        try await AgentService.shared.runRole(system: systemPrompt, user: payload)
    }

    private let systemPrompt = """
    You are the CRITIC AGENT (Quality Reviewer), the FINAL agent in a multi-agent travel system.
    You receive CONTEXT and the DRAFT itinerary. Validate and fix: exactly numberOfDays days, NO
    consecutive-day attraction repeats, each dayTotalCost within dailyBudget, sensible pacing, and
    the user's preferences respected. Use each day's date, condition, temperature, uvIndex and
    category (as weather.recommendation) from CONTEXT. Add a sensible packingList per day.
    totalTripCost must equal the sum of every dayTotalCost.
    Output ONLY the FINAL JSON (no markdown) in EXACTLY this shape:
    {"trip":{"city":"","startDate":"YYYY-MM-DD","numberOfDays":0,"dailyBudget":0,"currency":"",
    "totalTripCost":""},"days":[{"dayNumber":0,"date":"YYYY-MM-DD","weather":{"condition":"",
    "temperature":0,"uvIndex":0,"recommendation":""},"slots":[{"time":"08:00","endTime":"10:00",
    "type":"attraction","title":"","description":"","location":"","estimatedCost":"","tip":"",
    "durationMinutes":0}],"packingList":[""],"dayTotalCost":""}]}
    """
}

// MARK: - Orchestrator

final class TripAgentOrchestrator {
    static let shared = TripAgentOrchestrator()
    private init() {}

    let planner = PlannerAgent()
    let budgeter = BudgetAgent()
    let critic = CriticAgent()

    /// Runs the Planner → Budget → Critic pipeline and returns a finished Trip.
    /// `onStage` reports which agent is currently working (for the UI).
    func generate(city: String, startDate: String, numberOfDays: Int,
                  dailyBudget: Double, currency: String, preferences: String,
                  onStage: @MainActor @escaping (String) -> Void) async throws -> Trip {
        let days = max(1, min(numberOfDays, 7))
        let pace = DurationEstimatorService.currentPace().rawValue

        await onStage("Gathering weather & places…")
        let weatherByDay = try await WeatherService.shared.fetchMultiDayForecast(city: city, days: days)

        let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
        let start = dateFmt.date(from: startDate) ?? Date()

        // Shared context the agents collaborate on.
        var candidatesByCategory: [String: [Attraction]] = [:]
        var dayInfos: [[String: Any]] = []
        for i in 0..<days {
            let w = weatherByDay[min(i, weatherByDay.count - 1)]
            let category = MLRecommender.shared.predict(weather: w)
            if candidatesByCategory[category] == nil {
                candidatesByCategory[category] =
                    (try? await PlacesService.shared.searchAttractions(category: category, city: city, limit: 8)) ?? []
            }
            let dateStr = dateFmt.string(from: Calendar.current.date(byAdding: .day, value: i, to: start) ?? start)
            let candidates = (candidatesByCategory[category] ?? []).prefix(8).map {
                ["title": $0.name, "rating": $0.rating, "cost": $0.estimatedCost, "address": $0.address] as [String: Any]
            }
            dayInfos.append([
                "dayNumber": i + 1, "date": dateStr, "category": category,
                "condition": w.condition, "temperature": w.temperature, "uvIndex": w.uvIndex,
                "candidates": Array(candidates)
            ])
        }

        let context: [String: Any] = [
            "city": city, "startDate": startDate, "numberOfDays": days,
            "currency": currency, "dailyBudget": dailyBudget,
            "preferences": preferences.isEmpty ? "none" : preferences,
            "pace": pace, "days": dayInfos
        ]
        let contextJSON = json(context)

        // 1) Planner agent selects attractions per day.
        await onStage("🧭 Planner agent designing your days…")
        let plannerReply = try await planner.run(payload: contextJSON)
        let plannerJSON = await AgentService.shared.extractJSONObject(plannerReply)

        // 2) Budget agent builds costed, timed slots.
        await onStage("💰 Budget agent optimizing costs…")
        let budgetPayload = "CONTEXT:\n\(contextJSON)\n\nPLANNER SELECTIONS:\n\(plannerJSON)"
        let budgetReply = try await budgeter.run(payload: budgetPayload)
        let budgetJSON = await AgentService.shared.extractJSONObject(budgetReply)

        // 3) Critic agent validates and emits the final itinerary.
        await onStage("🔎 Critic agent reviewing & finalizing…")
        let criticPayload = "CONTEXT:\n\(contextJSON)\n\nDRAFT ITINERARY:\n\(budgetJSON)"
        let finalRaw = try await critic.run(payload: criticPayload)

        return try await AgentService.shared.parseTripJSON(finalRaw)
    }

    private func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}
