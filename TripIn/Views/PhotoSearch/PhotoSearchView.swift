import SwiftUI
import PhotosUI
import UIKit

struct PhotoSearchView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var vm = PhotoSearchViewModel()
    @StateObject private var searchVM = SearchViewModel()

    @State private var path: [PhotoRoute] = []
    @State private var showCamera = false
    @State private var showNearMe = false
    @State private var photoItem: PhotosPickerItem?
    @State private var cameraImage: UIImage?
    @State private var selectedAttraction: Attraction?

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    enum PhotoRoute: Hashable { case citySelector, results }

    var body: some View {
        NavigationStack(path: $path) {
            stepOne
                .navigationTitle("Photo Search")
                .navigationDestination(for: PhotoRoute.self) { route in
                    switch route {
                    case .citySelector: citySelector
                    case .results:      results
                    }
                }
        }
    }

    // MARK: - Step 1: photo input

    private var stepOne: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 20) {
                if cameraAvailable {
                    Button { showCamera = true } label: {
                        tile(icon: "camera.fill", title: "Take a Photo")
                    }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    tile(icon: "photo.on.rectangle", title: "Choose from Gallery")
                }
                if vm.isClassifying {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.coral)
                        Text("Analyzing photo…").foregroundColor(Theme.navy)
                    }
                }
                Spacer()
            }
            .padding(Theme.padding)
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView(image: $cameraImage, isPresented: $showCamera)
                .ignoresSafeArea()
        }
        .onChange(of: showCamera) { presented in
            if !presented, let image = cameraImage { handlePicked(image) }
        }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    handlePicked(image.compressedTo(maxSizeMB: 1.0))
                }
                photoItem = nil
            }
        }
    }

    private func tile(icon: String, title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 44)).foregroundColor(Theme.coral)
            Text(title).font(.title3.bold()).foregroundColor(Theme.navy)
        }
        .frame(maxWidth: .infinity).frame(height: 150)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .stroke(Theme.coral.opacity(0.3), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
    }

    private func handlePicked(_ image: UIImage) {
        cameraImage = nil
        Task {
            await vm.classifySelectedImage(image)
            path.append(.citySelector)
        }
    }

    // MARK: - Step 2: city selector

    private var citySelector: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        if let image = vm.selectedImage {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(width: 120, height: 120).clipped().cornerRadius(16)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scene detected").font(.caption).foregroundColor(Theme.textSecondary)
                            Text("\(sceneEmoji(vm.detectedScene)) \(vm.detectedScene.capitalized)")
                                .font(.headline).foregroundColor(Theme.navy)
                        }
                        Spacer()
                    }

                    Text("Where do you want to go?").font(.headline).foregroundColor(Theme.navy)

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Type a city…", text: $vm.cityQuery).foregroundColor(Theme.navy)
                            .autocorrectionDisabled()
                        if !vm.cityQuery.isEmpty {
                            Button { vm.clearCity() } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding().background(Theme.card).cornerRadius(Theme.buttonRadius)
                    .onChange(of: vm.cityQuery) { query in vm.onCityQueryChanged(query) }

                    if vm.isSearchingSuggestions {
                        ProgressView().tint(Theme.coral)
                    }
                    if !vm.citysuggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(vm.citysuggestions) { suggestion in
                                Button { vm.selectCity(suggestion) } label: {
                                    HStack {
                                        Text("📍 \(suggestion.fullName)").foregroundColor(Theme.navy)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10).padding(.horizontal, 12)
                                }
                                Divider()
                            }
                        }
                        .background(Theme.card).cornerRadius(Theme.buttonRadius)
                    }

                    HStack {
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                        Text("Or use my location").font(.caption).foregroundColor(Theme.textSecondary)
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                    }

                    Button { showNearMe = true } label: {
                        Label("Use Current Location", systemImage: "location.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(Theme.coral)

                    Button {
                        Task {
                            await vm.searchWithPhotoAndCity(searchViewModel: searchVM)
                            path.append(.results)
                        }
                    } label: {
                        if searchVM.isLoading {
                            ProgressView().tint(Theme.coral).frame(maxWidth: .infinity)
                        } else {
                            Text("Find Places Like This Photo").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(vm.selectedCity.isEmpty || searchVM.isLoading)
                }
                .padding(Theme.padding)
            }
        }
        .navigationTitle("Choose City")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNearMe) {
            NearMeView().environmentObject(authViewModel)
        }
    }

    private func sceneEmoji(_ scene: String) -> String {
        switch scene {
        case "beach":    return "🏖"
        case "nature":   return "🌿"
        case "cultural": return "🏛"
        default:          return "🧭"
        }
    }

    // MARK: - Results (reuses AttractionCardView + existing SearchViewModel)

    private var results: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    if searchVM.isLoading {
                        ProgressView("Finding places…").tint(Theme.coral).foregroundColor(Theme.navy).padding(.top, 40)
                    } else if searchVM.results.isEmpty {
                        Text("No places found. Try another city.")
                            .foregroundColor(Theme.textSecondary).padding(.top, 40)
                    } else {
                        ForEach(searchVM.results) { attraction in
                            Button { selectedAttraction = attraction } label: {
                                AttractionCardView(attraction: attraction)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Theme.padding)
            }
        }
        .navigationTitle(searchVM.city.isEmpty ? "Results" : searchVM.city)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedAttraction) { attraction in
            NavigationStack { AttractionDetailView(attraction: attraction) }
                .environmentObject(authViewModel)
        }
    }
}
