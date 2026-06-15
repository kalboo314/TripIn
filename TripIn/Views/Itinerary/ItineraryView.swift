import SwiftUI
import MapKit

struct ItineraryView: View {
    let itinerary: ItineraryDay
    var isReadOnly: Bool = false

    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = ItineraryViewModel()

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    private var pins: [PinItem] {
        itinerary.slots.compactMap { slot in
            slot.coordinate.map { PinItem(id: slot.id, coordinate: $0, title: slot.title) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !pins.isEmpty {
                    Map(coordinateRegion: $region, annotationItems: pins) { pin in
                        MapMarker(coordinate: pin.coordinate, tint: Theme.coral)
                    }
                    .frame(height: 200)
                    .cornerRadius(Theme.cardRadius)
                    .allowsHitTesting(false)
                }

                header
                timeline
                packingSection
                costFooter
                if let error = viewModel.errorMessage {
                    Text(error).font(.footnote).foregroundColor(.red)
                }
                actionButtons
            }
            .padding(Theme.padding)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(itinerary.city)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let r = computeRegion() { region = r }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(itinerary.city).font(.title2.bold()).foregroundColor(Theme.navy)
                Text(itinerary.date).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: icon(for: itinerary.weather.condition))
                Text("\(Int(itinerary.weather.temperature))°C")
            }
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.coral)
            .cornerRadius(Theme.buttonRadius)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeline: some View {
        VStack(spacing: 12) {
            ForEach(itinerary.slots) { slot in
                TimeSlotCardView(slot: slot)
            }
        }
    }

    private var packingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Packing List", systemImage: "bag.fill")
                .font(.headline)
                .foregroundColor(Theme.navy)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(itinerary.packingList, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.coral.opacity(0.12))
                        .foregroundColor(Theme.coral)
                        .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var costFooter: some View {
        HStack {
            Text("Total estimated cost").font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(itinerary.totalEstimatedCost).font(.headline).foregroundColor(Theme.navy)
        }
        .padding(Theme.padding)
        .background(Theme.card)
        .cornerRadius(Theme.cardRadius)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if !isReadOnly {
                Button {
                    Task {
                        if let uid = authViewModel.currentUser?.id {
                            await viewModel.save(itinerary, for: uid)
                        }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Label(viewModel.didSave ? "Saved" : "Save Trip",
                              systemImage: viewModel.didSave ? "checkmark.circle.fill" : "bookmark.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isSaving || viewModel.didSave)
            }

            ShareLink(item: viewModel.shareSummary(itinerary)) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: - Helpers

    private func computeRegion() -> MKCoordinateRegion? {
        let coords = pins.map { $0.coordinate }
        guard !coords.isEmpty else { return nil }
        let lats = coords.map { $0.latitude }
        let lngs = coords.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.02, (lats.max()! - lats.min()!) * 1.5),
            longitudeDelta: max(0.02, (lngs.max()! - lngs.min()!) * 1.5)
        )
        return MKCoordinateRegion(center: center, span: span)
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

/// Map annotation wrapper (CLLocationCoordinate2D isn't Identifiable).
struct PinItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
}
