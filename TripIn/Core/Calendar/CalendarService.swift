import Foundation
import EventKit

enum CalendarError: LocalizedError {
    case accessDenied
    case noCalendar
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Calendar access denied. Enable it in Settings to add trips."
        case .noCalendar:   return "No default calendar is available to add events to."
        case .saveFailed:   return "Could not add events to your calendar. Please try again."
        }
    }
}

final class CalendarService {
    static let shared = CalendarService()
    private init() {}

    private let store = EKEventStore()

    /// Adds every slot of every day as a calendar event. Returns how many were added.
    func addTrip(_ trip: Trip) async throws -> Int {
        guard try await requestAccess() else { throw CalendarError.accessDenied }
        guard let calendar = store.defaultCalendarForNewEvents else { throw CalendarError.noCalendar }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var count = 0
        for day in trip.days {
            for slot in day.slots {
                guard let start = formatter.date(from: "\(day.date) \(slot.time)") else { continue }
                let end = formatter.date(from: "\(day.date) \(slot.endTime)")
                    ?? start.addingTimeInterval(TimeInterval(max(30, slot.durationMinutes) * 60))

                let event = EKEvent(eventStore: store)
                event.title = slot.title
                event.location = slot.location.isEmpty ? trip.city : slot.location
                event.startDate = start
                event.endDate = max(end, start.addingTimeInterval(600))
                event.calendar = calendar

                var notes = slot.description
                if !slot.tip.isEmpty { notes += "\n\n💡 \(slot.tip)" }
                if !slot.estimatedCost.isEmpty { notes += "\n💰 \(slot.estimatedCost)" }
                event.notes = notes.isEmpty ? nil : notes

                do {
                    try store.save(event, span: .thisEvent, commit: false)
                    count += 1
                } catch {
                    throw CalendarError.saveFailed
                }
            }
        }

        do { try store.commit() } catch { throw CalendarError.saveFailed }
        return count
    }

    private func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(to: .event) { granted, error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: granted) }
            }
        }
    }
}
