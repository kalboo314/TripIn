import SwiftUI

struct AttractionCardView: View {
    let attraction: Attraction
    var isAdded: Bool = false
    var onAdd: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo

            VStack(alignment: .leading, spacing: 8) {
                Text(attraction.name)
                    .font(.headline)
                    .foregroundColor(Theme.navy)
                    .lineLimit(1)

                HStack {
                    categoryBadge
                    Spacer()
                    costBadge
                }

                ratingStars

                if let onAdd = onAdd {
                    Button(action: onAdd) {
                        Label(isAdded ? "Added to itinerary" : "Add to itinerary",
                              systemImage: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isAdded ? .green : Theme.coral)
                    .padding(.top, 4)
                }
            }
            .padding(Theme.padding)
        }
        .background(Theme.card)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
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
        .frame(height: 160)
        .clipped()
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
            .font(.caption).bold()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.coral.opacity(0.15))
            .foregroundColor(Theme.coral)
            .cornerRadius(6)
    }

    private var costBadge: some View {
        Text(attraction.estimatedCost)
            .font(.caption).bold()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color(.systemGray6))
            .foregroundColor(.secondary)
            .cornerRadius(6)
    }

    private var ratingStars: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: starName(for: index))
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
            Text(String(format: "%.1f", attraction.rating))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 2)
        }
    }

    private func starName(for index: Int) -> String {
        let value = Double(index)
        if value + 1 <= attraction.rating { return "star.fill" }
        if value + 0.5 <= attraction.rating { return "star.leadinghalf.filled" }
        return "star"
    }
}
