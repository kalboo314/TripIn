import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service = AuthService.shared

    func startObservingAuthState() {
        service.observeAuthState { [weak self] user in
            self?.currentUser = user
            self?.isAuthenticated = (user != nil)
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await service.signIn(email: email, password: password)
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = friendlyMessage(error)
        }
    }

    func signUp(email: String, password: String, displayName: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await service.signUp(email: email, password: password, displayName: displayName)
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = friendlyMessage(error)
        }
    }

    func signOut() {
        do {
            try service.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = "Could not sign out. Please try again."
        }
    }

    private func friendlyMessage(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
    }
}
