import SwiftUI
import MapKit

struct ItineraryView: View {
    let trip: Trip
    var isReadOnly: Bool = false

    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = ItineraryViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay = 0
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var legEstimates: [String] = []
    @State private var isAddingToCalendar = false
    @State private var showCalendarAlert = false
    @State private var calendarMessage = ""

    private var day: ItineraryDay { trip.days[min(selectedDay, trip.days.count - 1)] }
    private var isMultiDay: Bool { trip.numberOfDays > 1 || trip.days.count > 1 }

    /// Cached (baked-in) legs if available, else the live free-estimator fallback.
    private var legs: [String] { day.legEstimates ?? legEstimates }

    private var pins: [PinItem] {
        day.slots.compactMap { slot in
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

                tripHeader
                if isMultiDay { dayPicker }
                dayHeader
                timeline
                packingSection
                costFooter
                if let error = viewModel.errorMessage {
                    Text(error).font(.footnote).foregroundColor(.red)
                }
                actionButtons
                calendarButton
            }
            .padding(Theme.padding)
            .padding(.bottom, 90)
        }
        .background(Color(.systemGroupedBackground))
        .alert("Calendar", isPresented: $showCalendarAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(calendarMessage) }
        .navigationTitle(trip.city)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if let r = computeRegion() { region = r } }
        .onChange(of: selectedDay) { _ in
            if let r = computeRegion() { region = r }
        }
        .task(id: selectedDay) {
            // Use baked-in legs when present; otherwise compute the free estimate live.
            if day.legEstimates == nil {
                legEstimates = await TravelEstimator.shared.legEstimates(for: day.slots)
            } else {
                legEstimates = []
            }
        }
        .toolbar {
            if isReadOnly {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // Editing is single-day only for now.
                        if !isMultiDay {
                            Button { showEdit = true } label: { Label("Edit", systemImage: "pencil") }
                        }
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("Delete this trip?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deleteTrip() } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                EditItineraryView(viewModel: .edit(trip))
            }
            .environmentObject(authViewModel)
        }
    }

    private func deleteTrip() async {
        guard let uid = authViewModel.currentUser?.id else { return }
        do {
            try await FirestoreService.shared.deleteTrip(tripId: trip.id, for: uid)
            dismiss()
        } catch {
            viewModel.errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not delete trip. Please try again."
        }
    }

    // MARK: - Sections

    private var tripHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.city).font(.title2.bold()).foregroundColor(Theme.navy)
                Text(isMultiDay
                     ? "\(trip.startDate) · \(trip.numberOfDays) days"
                     : trip.startDate)
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Trip total").font(.caption2).foregroundColor(.secondary)
                Text(trip.totalTripCost).font(.subheadline.bold()).foregroundColor(Theme.navy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dayPicker: some View {
        Picker("Day", selection: $selectedDay) {
            ForEach(0..<trip.days.count, id: \.self) { index in
                Text("Day \(index + 1)").tag(index)
            }
        }
        .pickerStyle(.segmented)
    }

    private var dayHeader: some View {
        HStack {
            Text(day.date).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: icon(for: day.weather.condition))
                Text("\(Int(day.weather.temperature))°C")
            }
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.coral)
            .cornerRadius(Theme.buttonRadius)
        }
    }

    private var timeline: some View {
        VStack(spacing: 12) {
            ForEach(Array(day.slots.enumerated()), id: \.element.id) { index, slot in
                TimeSlotCardView(slot: slot)
                if index < day.slots.count - 1,
                   index < legs.count,
                   !legs[index].isEmpty {
                    legConnector(legs[index])
                }
            }
        }
    }

    /// Travel distance/time estimate shown between two consecutive stops.
    private func legConnector(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            Spacer()
        }
    }

    private var packingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Packing List", systemImage: "bag.fill")
                .font(.headline)
                .foregroundColor(Theme.navy)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(day.packingList, id: \.self) { item in
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
            Text(isMultiDay ? "Day total" : "Total estimated cost")
                .font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(day.totalEstimatedCost).font(.headline).foregroundColor(Theme.navy)
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
                            await viewModel.save(trip, for: uid)
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

            ShareLink(item: viewModel.shareSummary(trip)) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var calendarButton: some View {
        Button { Task { await addToCalendar() } } label: {
            if isAddingToCalendar {
                ProgressView().tint(Theme.coral).frame(maxWidth: .infinity)
            } else {
                Label("Add to Calendar", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(isAddingToCalendar)
    }

    private func addToCalendar() async {
        isAddingToCalendar = true
        defer { isAddingToCalendar = false }
        do {
            let n = try await CalendarService.shared.addTrip(trip)
            calendarMessage = "Added \(n) event\(n == 1 ? "" : "s") to your Calendar."
        } catch {
            calendarMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not add to calendar."
        }
        showCalendarAlert = true
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
