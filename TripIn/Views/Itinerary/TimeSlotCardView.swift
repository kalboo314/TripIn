import SwiftUI

struct TimeSlotCardView: View {
    let slot: TimeSlot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timeline

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(slot.title)
                        .font(.headline)
                        .foregroundColor(Theme.navy)
                    Spacer()
                    Text(slot.estimatedCost)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }

                if !slot.description.isEmpty {
                    Text(slot.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Label("\(slot.time)–\(slot.endTime)", systemImage: "clock")
                    Label("\(slot.durationMinutes) min", systemImage: "hourglass")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if !slot.tip.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill").foregroundColor(.yellow)
                        Text(slot.tip)
                            .font(.caption)
                            .foregroundColor(Theme.navy.opacity(0.85))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.12))
                    .cornerRadius(8)
                }
            }
            .padding(Theme.padding)
            .background(Theme.card)
            .cornerRadius(Theme.cardRadius)
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
    }

    private var timeline: some View {
        VStack(spacing: 4) {
            Text(slot.time)
                .font(.caption2.bold())
                .foregroundColor(Theme.navy)
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Theme.coral)
            Rectangle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 48)
    }

    private var icon: String {
        switch slot.type {
        case .attraction: return "mappin.circle.fill"
        case .meal:       return "fork.knife"
        case .travel:     return "car.fill"
        case .rest:       return "bed.double.fill"
        }
    }
}
