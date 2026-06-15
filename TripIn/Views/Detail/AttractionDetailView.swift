import SwiftUI
import MapKit

struct AttractionDetailView: View {
    let attraction: Attraction
    var onAddToItinerary: ((Attraction) -> Void)?

    @State private var tips: AttractionTips?
    @State private var isLoadingTips = false
    @State private var tipsError: String?

    @State private var added: Bool
    @State private var region: MKCoordinateRegion

    init(attraction: Attraction,
         isInItinerary: Bool = false,
         onAddToItinerary: ((Attraction) -> Void)? = nil) {
        self.attraction = attraction
        self.onAddToItinerary = onAddToItinerary
        _added = State(initialValue: isInItinerary)
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: attraction.latitude, longitude: attraction.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    private var hasCoordinate: Bool { attraction.latitude != 0 || attraction.longitude != 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                photoHeader
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    infoRows
                    if hasCoordinate { mapSnippet }
                    tipsSection
                    actionButtons
                }
                .padding(Theme.padding)
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var photoHeader: some View {
        AsyncImage(url: URL(string: attraction.photoUrl)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .empty:
                ZStack { Color(.systemGray5); ProgressView() }
            case .failure:
                ZStack { Color(.systemGray5); Image(systemName: "photo").font(.largeTitle).foregroundColor(.gray) }
            @unknown default:
                Color(.systemGray5)
            }
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(attraction.name)
                .font(.title.bold())
                .foregroundColor(Theme.navy)
            HStack(spacing: 8) {
                Text(attraction.category.capitalized)
                    .font(.caption).bold()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.coral.opacity(0.15))
                    .foregroundColor(Theme.coral)
                    .cornerRadius(6)
                Label(String(format: "%.1f", attraction.rating), systemImage: "star.fill")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(attraction.estimatedCost)
                    .font(.caption).bold()
                    .foregroundColor(.secondary)
            }
        }
    }

    private var infoRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !attraction.address.isEmpty {
                infoRow(icon: "mappin.and.ellipse", text: attraction.address)
            }
            if !attraction.openingHours.isEmpty {
                infoRow(icon: "clock", text: attraction.openingHours)
            }
        }
        .padding(Theme.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .cornerRadius(Theme.cardRadius)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundColor(Theme.coral).frame(width: 20)
            Text(text).font(.subheadline).foregroundColor(Theme.navy)
            Spacer(minLength: 0)
        }
    }

    private var mapSnippet: some View {
        Map(coordinateRegion: .constant(region),
            annotationItems: [PinItem(id: attraction.id,
                                      coordinate: region.center,
                                      title: attraction.name)]) { pin in
            MapMarker(coordinate: pin.coordinate, tint: Theme.coral)
        }
        .frame(height: 180)
        .cornerRadius(Theme.cardRadius)
        .allowsHitTesting(false)
    }

    // MARK: - AI tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let tips = tips {
                tipCard(icon: "tshirt.fill", title: "What to wear", text: tips.wear)
                tipCard(icon: "bag.fill", title: "What to bring", text: tips.bring)
                tipCard(icon: "clock.badge.checkmark", title: "Best time to visit", text: tips.bestTime)
            } else {
                Button {
                    Task { await loadTips() }
                } label: {
                    if isLoadingTips {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Label("Get AI Tips", systemImage: "sparkles").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoadingTips)

                if let tipsError = tipsError {
                    Text(tipsError).font(.footnote).foregroundColor(.red)
                }
            }
        }
    }

    private func tipCard(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundColor(Theme.coral).font(.title3).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold()).foregroundColor(Theme.navy)
                Text(text).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .cornerRadius(Theme.cardRadius)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButtons: some View {
        if let onAddToItinerary {
            Button {
                onAddToItinerary(attraction)
                added.toggle()
            } label: {
                Label(added ? "Added to itinerary" : "Add to itinerary",
                      systemImage: added ? "checkmark.circle.fill" : "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .tint(added ? .green : Theme.coral)
        }
    }

    private func loadTips() async {
        tipsError = nil
        isLoadingTips = true
        defer { isLoadingTips = false }
        do {
            tips = try await AgentService.shared.attractionTips(for: attraction)
        } catch {
            tipsError = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't load tips. Please try again."
        }
    }

}
