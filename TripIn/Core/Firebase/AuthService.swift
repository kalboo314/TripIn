import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AuthError: LocalizedError {
    case signUpFailed
    case signInFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .signUpFailed:     return "Could not create your account. Please try again."
        case .signInFailed:     return "Incorrect email or password."
        case .notAuthenticated: return "You are not signed in."
        }
    }
}

@MainActor
final class AuthService {
    static let shared = AuthService()
    private init() {}

    private let db = Firestore.firestore()
    private var stateListener: AuthStateDidChangeListenerHandle?

    /// Creates the account, sets the Auth profile name, and stores the user in Firestore.
    func signUp(email: String, password: String, displayName: String) async throws -> AppUser {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            let change = result.user.createProfileChangeRequest()
            change.displayName = displayName
            try await change.commitChanges()

            let user = AppUser(id: result.user.uid, email: email, displayName: displayName)
            try await db.collection("users").document(user.id).setData([
                "email": email,
                "displayName": displayName,
                "createdAt": FieldValue.serverTimestamp()
            ])
            return user
        } catch {
            throw AuthError.signUpFailed
        }
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let u = result.user
            return AppUser(id: u.uid, email: u.email ?? email, displayName: u.displayName ?? "")
        } catch {
            throw AuthError.signInFailed
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    /// Persists auth state across launches. `onChange` is delivered on the main thread.
    func observeAuthState(_ onChange: @escaping (AppUser?) -> Void) {
        stateListener = Auth.auth().addStateDidChangeListener { _, user in
            if let user = user {
                onChange(AppUser(id: user.uid, email: user.email ?? "", displayName: user.displayName ?? ""))
            } else {
                onChange(nil)
            }
        }
    }
}
