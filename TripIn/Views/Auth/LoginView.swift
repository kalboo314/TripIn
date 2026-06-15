import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        header

                        VStack(spacing: 16) {
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
                                Task { await authViewModel.signIn(email: email, password: password) }
                            } label: {
                                if authViewModel.isLoading {
                                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                                } else {
                                    Text("Sign In").frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                        }
                        .padding(Theme.padding)
                        .background(Theme.card)
                        .cornerRadius(Theme.cardRadius)
                        .padding(.horizontal, Theme.padding)

                        Button { showRegister = true } label: {
                            HStack(spacing: 4) {
                                Text("Don't have an account?").foregroundColor(.white.opacity(0.7))
                                Text("Register").foregroundColor(Theme.coral).bold()
                            }
                            .font(.subheadline)
                        }

                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationDestination(isPresented: $showRegister) { RegisterView() }
            .onAppear { authViewModel.errorMessage = nil }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 52))
                .foregroundColor(Theme.coral)
            Text("TripIn")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text("Plan your perfect day, rain or shine.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 60)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView().environmentObject(AuthViewModel())
    }
}
