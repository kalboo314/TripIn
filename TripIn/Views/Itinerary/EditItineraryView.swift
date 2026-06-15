import SwiftUI

struct EditItineraryView: View {
    @StateObject var viewModel: TripBuilderViewModel
    var onSaved: (() -> Void)? = nil

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pickerMode: PickerMode?

    private enum PickerMode: Identifiable {
        case add
        case replace(String)
        var id: String {
            switch self {
            case .add: return "add"
            case .replace(let slotId): return "replace-\(slotId)"
            }
        }
    }

    var body: some View {
        Form {
            Section("Trip") {
                TextField("City", text: $viewModel.city)
                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
            }

            Section("Places") {
                ForEach(viewModel.slots) { slot in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(slot.title).font(.subheadline.bold()).foregroundColor(Theme.navy)
                            Text("\(slot.time)–\(slot.endTime)").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            pickerMode = .replace(slot.id)
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.borderless)
                        .tint(Theme.coral)
                    }
                }
                .onDelete { viewModel.remove(at: $0) }
                .onMove { viewModel.move(from: $0, to: $1) }

                Button { pickerMode = .add } label: {
                    Label("Add place", systemImage: "plus")
                }
            }

            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundColor(.red).font(.footnote) }
            }

            Section {
                Button { Task { await save() } } label: {
                    if viewModel.isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(viewModel.isEditing ? "Save Changes" : "Save Trip")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
                .disabled(viewModel.isSaving || viewModel.slots.isEmpty)
            }
        }
        .navigationTitle(viewModel.isEditing ? "Edit Trip" : "Build Itinerary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
        }
        .sheet(item: $pickerMode) { mode in
            PlacePickerView(city: viewModel.city) { attraction in
                switch mode {
                case .add:                  viewModel.addAttraction(attraction)
                case .replace(let slotId):  viewModel.replace(slotId: slotId, with: attraction)
                }
            }
        }
    }

    private func save() async {
        guard let uid = authViewModel.currentUser?.id else { return }
        if await viewModel.save(for: uid) {
            onSaved?()
            dismiss()
        }
    }
}
