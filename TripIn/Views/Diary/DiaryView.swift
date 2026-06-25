import SwiftUI

struct DiaryView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = DiaryViewModel()
    @State private var showAdd = false

    private var userId: String? { authViewModel.currentUser?.id }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                Group {
                    if viewModel.isLoading && viewModel.entries.isEmpty {
                        ProgressView().tint(Theme.coral)
                    } else if viewModel.entries.isEmpty {
                        emptyState
                    } else {
                        feed
                    }
                }
            }
            .navigationTitle("Travel Diary")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .tint(Theme.coral)
                }
            }
            .onAppear { Task { await load() } }
            .sheet(isPresented: $showAdd, onDismiss: { Task { await load() } }) {
                AddDiaryEntryView(viewModel: viewModel).environmentObject(authViewModel)
            }
        }
    }

    private var feed: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 18) {
                ForEach(viewModel.entries) { entry in card(entry) }
            }
            .padding(Theme.padding)
            .padding(.bottom, 90)
        }
        .refreshable { await load() }
    }

    private func card(_ entry: DiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let img = decoded(entry) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack { Color(.systemGray5); Image(systemName: "photo").foregroundColor(.gray) }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 260).clipped()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    tagChip(entry.sceneTag)
                    Spacer()
                    Text(dateText(entry.createdAt)).font(.caption).foregroundColor(Theme.textSecondary)
                }
                if !entry.caption.isEmpty {
                    Text(entry.caption).font(.subheadline).foregroundColor(Theme.navy)
                }
                if !entry.place.isEmpty {
                    Label(entry.place, systemImage: "mappin.and.ellipse")
                        .font(.caption).foregroundColor(Theme.textSecondary)
                }
            }
            .padding(Theme.padding)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        .contextMenu {
            Button(role: .destructive) {
                Task { if let uid = userId { await viewModel.delete(entry, for: uid) } }
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        Text("\(sceneEmoji(tag)) \(tag.capitalized)")
            .font(.caption2).bold()
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Theme.coral.opacity(0.15)).foregroundColor(Theme.coral)
            .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed").font(.system(size: 44)).foregroundColor(Theme.textSecondary)
            Text("Your travel diary is empty").font(.headline).foregroundColor(Theme.navy)
            Text("Tap + to add your first travel memory.")
                .font(.subheadline).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center)
            Button { showAdd = true } label: {
                Label("Add a memory", systemImage: "plus").frame(maxWidth: 220)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 4)
        }
        .padding()
    }

    private func load() async {
        guard let uid = userId else { return }
        await viewModel.load(for: uid)
    }

    // Decode base64 once per entry, cached so scrolling doesn't re-decode.
    private static let imageCache = NSCache<NSString, UIImage>()
    private func decoded(_ entry: DiaryEntry) -> UIImage? {
        if let cached = Self.imageCache.object(forKey: entry.id as NSString) { return cached }
        guard let data = Data(base64Encoded: entry.imageData),
              let img = UIImage(data: data) else { return nil }
        Self.imageCache.setObject(img, forKey: entry.id as NSString)
        return img
    }

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f.string(from: date)
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
