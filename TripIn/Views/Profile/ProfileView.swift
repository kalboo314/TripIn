import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tripIn_userPace") private var userPace: UserPace = .moderate

    private var name: String {
        let n = authViewModel.currentUser?.displayName ?? ""
        return n.isEmpty ? "Traveler" : n
    }
    private var email: String { authViewModel.currentUser?.email ?? "" }
    private var initial: String {
        String(name.first ?? email.first ?? "U").uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        avatar

                        VStack(spacing: 4) {
                            Text(name).font(.title2.bold()).foregroundColor(Theme.navy)
                            if !email.isEmpty {
                                Text(email).font(.subheadline).foregroundColor(Theme.textSecondary)
                            }
                        }

                        VStack(spacing: 0) {
                            row(icon: "person.fill", title: "Name", value: name)
                            Divider().padding(.leading, 48)
                            row(icon: "envelope.fill", title: "Email", value: email.isEmpty ? "—" : email)
                        }
                        .cardSurface()

                        paceCard

                        Button(role: .destructive) {
                            authViewModel.signOut()
                            dismiss()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 8)
                    }
                    .padding(Theme.padding)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.tint(Theme.coral)
                }
            }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Theme.coralGradient)
                .frame(width: 96, height: 96)
                .shadow(color: Theme.coral.opacity(0.4), radius: 12, y: 6)
            Text(initial).font(.system(size: 40, weight: .bold)).foregroundColor(.white)
        }
    }

    private var paceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Travel Pace")
                .font(.subheadline.bold()).foregroundColor(Theme.navy)
                .padding(.horizontal, Theme.padding).padding(.top, Theme.padding).padding(.bottom, 8)

            ForEach(UserPace.allCases, id: \.self) { pace in
                Button { userPace = pace } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pace.displayName).font(.body).foregroundColor(Theme.navy)
                            Text(pace.description).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: userPace == pace ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(userPace == pace ? Theme.coral : Color(.systemGray4))
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, Theme.padding).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if pace != UserPace.allCases.last { Divider().padding(.leading, Theme.padding) }
            }

            Text("Affects how long the app estimates you'll spend at each attraction.")
                .font(.caption).foregroundColor(.secondary)
                .padding(.horizontal, Theme.padding).padding(.top, 6).padding(.bottom, Theme.padding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func row(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(Theme.coral).frame(width: 24)
            Text(title).foregroundColor(.secondary)
            Spacer()
            Text(value).foregroundColor(Theme.navy).fontWeight(.medium).lineLimit(1)
        }
        .padding(Theme.padding)
    }
}
