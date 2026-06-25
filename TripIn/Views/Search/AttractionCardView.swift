import SwiftUI

struct AttractionCardView: View {
    let attraction: Attraction
    var isAdded: Bool = false
    var onAdd: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo

            VStack(alignment: .leading, spacing: 10) {
                Text(attraction.name)
                    .font(.headline)
                    .foregroundColor(Theme.navy)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    categoryBadge
                    ratingPill
                    Spacer()
                    costBadge
                }

                if let onAdd = onAdd {
                    Button(action: onAdd) {
                        Label(isAdded ? "Added to itinerary" : "Add to itinerary",
                              systemImage: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isAdded ? .green : Theme.coral)
                    .controlSize(.regular)
                    .padding(.top, 2)
                }
            }
            .padding(14)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    // MARK: - Pieces

    private var photo: some View {
        AsyncImage(url: URL(string: attraction.photoUrl)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .empty:
                ZStack { Color(.systemGray5); ProgressView() }
            case .failure:
                placeholder
            @unknown default:
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .clipped()
        .overlay(
            // subtle bottom scrim so the white card meets the photo softly
            LinearGradient(colors: [.clear, .black.opacity(0.18)],
                           startPoint: .center, endPoint: .bottom)
        )
    }

    private var placeholder: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }

    private var categoryBadge: some View {
        Text(attraction.category.capitalized)
            .font(.caption2).bold()
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Theme.coral.opacity(0.15))
            .foregroundColor(Theme.coral)
            .clipShape(Capsule())
    }

    private var ratingPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill").font(.system(size: 9))
            Text(String(format: "%.1f", attraction.rating)).font(.caption2.bold())
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color.yellow.opacity(0.18))
        .foregroundColor(.orange)
        .clipShape(Capsule())
        .opacity(attraction.rating > 0 ? 1 : 0)
    }

    private var costBadge: some View {
        Text(attraction.estimatedCost)
            .font(.caption2).bold()
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Color(.systemGray6))
            .foregroundColor(.secondary)
            .clipShape(Capsule())
    }
}
