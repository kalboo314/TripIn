import SwiftUI
import UIKit

/// Central design tokens — light/pastel travel-app palette.
enum Theme {
    static let coral = Color(red: 0xFF / 255, green: 0x6B / 255, blue: 0x6B / 255)  // #FF6B6B
    static let coralDeep = Color(red: 0xFF / 255, green: 0x47 / 255, blue: 0x6B / 255)
    static let card  = Color.white

    /// Primary dark text on light surfaces.
    static let navy = Color(red: 0x2A / 255, green: 0x2E / 255, blue: 0x43 / 255)
    static let textPrimary = navy
    static let textSecondary = Color(red: 0x8A / 255, green: 0x8F / 255, blue: 0xA3 / 255)

    static let cardRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 16
    static let padding: CGFloat = 16

    /// Soft pastel full-screen background.
    static let backgroundGradient = LinearGradient(
        colors: [Color(red: 0.99, green: 0.95, blue: 0.96),
                 Color(red: 0.96, green: 0.97, blue: 0.99)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Coral fill used on primary buttons, the tab bar, and accents.
    static let coralGradient = LinearGradient(
        colors: [coral, coralDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - View styling helpers

extension View {
    /// Standard white card surface with continuous corners + soft shadow.
    func cardSurface(cornerRadius: CGFloat = Theme.cardRadius) -> some View {
        self
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

// MARK: - Buttons

/// Coral gradient, full-width primary action button.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(Theme.coralGradient)
            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
            .shadow(color: Theme.coral.opacity(0.35),
                    radius: configuration.isPressed ? 4 : 12,
                    y: configuration.isPressed ? 2 : 7)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Soft coral-tinted outline button for secondary actions on light backgrounds.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundColor(Theme.coral)
            .padding(.vertical, 13)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(Theme.coral.opacity(configuration.isPressed ? 0.18 : 0.10))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                    .stroke(Theme.coral.opacity(0.35), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Shared components

/// Centered icon + title (+ optional message and retry action) for empty/error states.
struct InfoStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var tint: Color = Theme.textSecondary
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 46, weight: .light))
                .foregroundColor(tint)
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.navy)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
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

/// Icon + text/secure field used on the auth and search screens.
struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(Theme.coral)
                .frame(width: 22)
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                .fill(Color(.systemGray6)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1))
    }
}
