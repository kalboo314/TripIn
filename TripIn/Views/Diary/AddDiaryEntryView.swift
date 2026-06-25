import SwiftUI
import PhotosUI
import UIKit

struct AddDiaryEntryView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject var viewModel: DiaryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var caption = ""
    @State private var place = ""
    @State private var detectedTag = ""
    @State private var isClassifying = false
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var photoItem: PhotosPickerItem?

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if let image { photoPreview(image) } else { photoPickers }
                        if image != nil { detailsCard }
                        if let error = viewModel.errorMessage {
                            Text(error).font(.footnote).foregroundColor(.red)
                        }
                        saveButton
                    }
                    .padding(Theme.padding)
                }
            }
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView(image: $cameraImage, isPresented: $showCamera).ignoresSafeArea()
            }
            .onChange(of: showCamera) { presented in
                if !presented, let img = cameraImage { handlePicked(img) }
            }
            .onChange(of: photoItem) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        handlePicked(img.compressedTo(maxSizeMB: 1.0))
                    }
                    photoItem = nil
                }
            }
        }
    }

    // MARK: - Photo input

    private var photoPickers: some View {
        VStack(spacing: 12) {
            if cameraAvailable {
                Button { showCamera = true } label: { tile(icon: "camera.fill", title: "Take a Photo") }
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                tile(icon: "photo.on.rectangle", title: "Choose from Gallery")
            }
        }
    }

    private func tile(icon: String, title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundColor(Theme.coral)
            Text(title).font(.headline).foregroundColor(Theme.navy)
        }
        .frame(maxWidth: .infinity).frame(height: 130)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .stroke(Theme.coral.opacity(0.3), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
    }

    private func photoPreview(_ img: UIImage) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(height: 280).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))

            HStack(spacing: 6) {
                if isClassifying {
                    ProgressView().tint(.white)
                    Text("Detecting…").font(.caption.bold())
                } else {
                    Text("\(sceneEmoji(detectedTag)) \(detectedTag.capitalized)").font(.caption.bold())
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            Button { image = nil; detectedTag = "" } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
                    .foregroundColor(.white).shadow(radius: 3)
            }
            .padding(12)
        }
    }

    private var detailsCard: some View {
        VStack(spacing: 12) {
            TextField("Write a caption…", text: $caption, axis: .vertical)
                .lineLimit(2...5)
            Divider()
            HStack {
                Image(systemName: "mappin.and.ellipse").foregroundColor(Theme.coral)
                TextField("Place (optional)", text: $place)
            }
        }
        .padding(Theme.padding)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
    }

    private var saveButton: some View {
        Button {
            Task {
                guard let uid = authViewModel.currentUser?.id, let img = image else { return }
                let ok = await viewModel.addEntry(image: img, caption: caption, place: place,
                                                  sceneTag: detectedTag, for: uid)
                if ok { dismiss() }
            }
        } label: {
            if viewModel.isUploading {
                HStack(spacing: 8) { ProgressView().tint(.white); Text("Saving…") }.frame(maxWidth: .infinity)
            } else {
                Label("Save to Diary", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(image == nil || viewModel.isUploading)
    }

    // MARK: - Helpers

    private func handlePicked(_ img: UIImage) {
        cameraImage = nil
        image = img
        detectedTag = ""
        isClassifying = true
        Task {
            detectedTag = (try? await SceneClassifierService.shared.classify(image: img)) ?? "outdoor"
            isClassifying = false
        }
    }

    private func sceneEmoji(_ tag: String) -> String {
        switch tag {
        case "beach":    return "🏖"
        case "nature":   return "🌿"
        case "cultural": return "🏛"
        default:          return "🧭"
        }
    }
}
