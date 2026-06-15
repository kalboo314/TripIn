import SwiftUI
import UIKit

/// Central design tokens (colors, radii, spacing) per the design guidelines.
enum Theme {
    static let navy = Color(red: 0x1B / 255, green: 0x2A / 255, blue: 0x4A / 255)   // #1B2A4A
    static let coral = Color(red: 0xFF / 255, green: 0x6B / 255, blue: 0x6B / 255)  // #FF6B6B
    static let card = Color.white

    static let cardRadius: CGFloat = 16
    static let buttonRadius: CGFloat = 12
    static let padding: CGFloat = 16
}

// MARK: - Shared components

/// Coral, full-width primary action button.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.coral.opacity(configuration.isPressed ? 0.8 : 1))
            .cornerRadius(Theme.buttonRadius)
    }
}

/// Centered icon + title (+ optional message and retry action) for empty/error
/// states on light backgrounds. Never leave a screen blank.
struct InfoStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var tint: Color = .secondary
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(tint)
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.navy)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(Theme.coral)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Icon + text/secure field used on the auth screens.
struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(.secondary)
                .frame(width: 20)
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(Theme.buttonRadius)
    }
}
