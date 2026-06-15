import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            Theme.navy.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Create Account")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        Text("Start planning smarter trips.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 40)

                    VStack(spacing: 16) {
                        AuthTextField(placeholder: "Name", text: $displayName, systemImage: "person")
                        AuthTextField(placeholder: "Email", text: $email,
                                      systemImage: "envelope", keyboard: .emailAddress)
                        AuthTextField(placeholder: "Password", text: $password,
                                      systemImage: "lock", isSecure: true)

                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(Theme.coral)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task {
                                await authViewModel.signUp(email: email,
                                                           password: password,
                                                           displayName: displayName)
                            }
                        } label: {
                            if authViewModel.isLoading {
                                ProgressView().tint(.white).frame(maxWidth: .infinity)
                            } else {
                                Text("Register").frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(authViewModel.isLoading || displayName.isEmpty
                                  || email.isEmpty || password.isEmpty)
                    }
                    .padding(Theme.padding)
                    .background(Theme.card)
                    .cornerRadius(Theme.cardRadius)
                    .padding(.horizontal, Theme.padding)

                    Button { dismiss() } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?").foregroundColor(.white.opacity(0.7))
                            Text("Sign In").foregroundColor(Theme.coral).bold()
                        }
                        .font(.subheadline)
                    }

                    Spacer(minLength: 20)
                }
            }
        }
        .onAppear { authViewModel.errorMessage = nil }
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView().environmentObject(AuthViewModel())
    }
}
