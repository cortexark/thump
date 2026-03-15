// AppleSignInView.swift
// Thump iOS
//
// Sign in with Apple screen — the first thing a new user sees.
// Displays the ThumpBuddy, app name, and a native Apple sign-in button.
// On success, stores the credential and calls the onSignedIn closure.
//
// Platforms: iOS 17+

import SwiftUI
import AuthenticationServices

// MARK: - AppleSignInView

/// Full-screen Sign in with Apple gate shown before legal acceptance
/// and onboarding. Uses Apple's native `SignInWithAppleButton` for
/// a consistent, trustworthy sign-in experience.
struct AppleSignInView: View {

    /// Called when the user successfully signs in.
    let onSignedIn: () -> Void

    /// Environment object for storing the user's name.
    @EnvironmentObject var localStore: LocalStore

    /// Error message shown in an alert if sign-in fails.
    @State private var errorMessage: String?

    /// Controls the error alert presentation.
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Buddy greeting
            ThumpBuddy(mood: .content, size: 120, tappable: false)
                .padding(.bottom, 16)

            // App name
            Text("Thump")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: 0x2563EB), Color(hex: 0x7C3AED)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Your Heart, Your Coach")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            // Privacy reassurance
            Label(
                "Your health data stays on your device",
                systemImage: "lock.shield.fill"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 24)

            // Sign in with Apple button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleSignInResult(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .cornerRadius(14)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)

            // Skip option for development/testing
            #if DEBUG
            Button("Skip Sign-In (Debug)") {
                onSignedIn()
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 8)
            #endif

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 24)
        .background(Color(.systemBackground))
        .alert("Sign-In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unexpected error occurred. Please try again.")
        }
        .accessibilityIdentifier("apple_sign_in_view")
    }

    // MARK: - Sign-In Handler

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                AppLogger.error("Sign-in succeeded but credential type is unexpected")
                errorMessage = "Unexpected credential type. Please try again."
                showError = true
                return
            }

            // Store the stable user identifier in Keychain
            AppleSignInService.saveUserIdentifier(credential.user)

            // Store name if provided (Apple only sends this on first sign-in)
            if let fullName = credential.fullName {
                let name = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !name.isEmpty {
                    localStore.profile.displayName = name
                    localStore.saveProfile()
                }
            }

            // Store email if provided
            if let email = credential.email {
                localStore.profile.email = email
                localStore.saveProfile()
            }

            InteractionLog.log(
                .buttonTap,
                element: "sign_in_with_apple",
                page: "SignIn",
                details: "success"
            )

            AppLogger.info("Sign in with Apple completed successfully")
            onSignedIn()

        case .failure(let error):
            // User cancelled is not a real error — don't show alert
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                AppLogger.info("Sign in with Apple cancelled by user")
                return
            }

            AppLogger.error("Sign in with Apple failed: \(error.localizedDescription)")
            errorMessage = "Sign-in failed: \(error.localizedDescription)"
            showError = true

            InteractionLog.log(
                .buttonTap,
                element: "sign_in_with_apple",
                page: "SignIn",
                details: "error: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Preview

#Preview("Sign In") {
    AppleSignInView { }
        .environmentObject(LocalStore())
}
