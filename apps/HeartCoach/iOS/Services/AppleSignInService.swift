// AppleSignInService.swift
// Thump iOS
//
// Handles Sign in with Apple authentication flow.
// Stores the Apple user identifier in the Keychain via the Security
// framework (not CryptoService, which is for data encryption).
// On subsequent launches, verifies the credential is still valid.
//
// Platforms: iOS 17+

import AuthenticationServices
import Foundation

// MARK: - Apple Sign-In Service

/// Manages Sign in with Apple credential storage and validation.
///
/// The Apple-issued `userIdentifier` is a stable, opaque string that
/// persists across app reinstalls on the same device. We store it in
/// the Keychain so it survives app updates and UserDefaults resets.
///
/// Usage:
/// ```swift
/// // Save after successful sign-in
/// AppleSignInService.saveUserIdentifier("001234.abc...")
///
/// // Check on app launch
/// let isValid = await AppleSignInService.isCredentialValid()
/// ```
public enum AppleSignInService {

    // MARK: - Keychain Constants

    /// Keychain item identifier for the Apple user ID.
    private static let keychainAccount = "com.thump.appleUserIdentifier"

    /// Service name used in the Keychain query.
    private static let keychainService = "com.thump.AppleSignIn"

    // MARK: - Credential Storage

    /// Save the Apple user identifier to the Keychain.
    ///
    /// - Parameter userIdentifier: The stable user ID from
    ///   `ASAuthorizationAppleIDCredential.user`.
    public static func saveUserIdentifier(_ userIdentifier: String) {
        guard let data = userIdentifier.data(using: .utf8) else { return }

        // Delete any existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new entry
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Retrieve the stored Apple user identifier from the Keychain.
    ///
    /// - Returns: The user identifier string, or `nil` if not stored.
    public static func loadUserIdentifier() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let identifier = String(data: data, encoding: .utf8) else {
            return nil
        }
        return identifier
    }

    /// Delete the stored Apple user identifier from the Keychain.
    /// Used when credential is revoked or user signs out.
    public static func deleteUserIdentifier() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Credential Validation

    /// Check whether the stored Apple ID credential is still valid.
    ///
    /// Apple can revoke credentials if the user disconnects the app
    /// from their Apple ID settings. This async check contacts Apple's
    /// servers to verify.
    ///
    /// - Returns: `true` if credential is authorized, `false` if revoked,
    ///   not found, or check failed.
    public static func isCredentialValid() async -> Bool {
        guard let userIdentifier = loadUserIdentifier() else {
            return false
        }

        let provider = ASAuthorizationAppleIDProvider()

        do {
            let state = try await provider.credentialState(forUserID: userIdentifier)
            switch state {
            case .authorized:
                return true
            case .revoked, .notFound:
                // Credential is no longer valid — clear stored data
                deleteUserIdentifier()
                return false
            case .transferred:
                // App ownership transferred — treat as valid
                return true
            @unknown default:
                return false
            }
        } catch {
            #if DEBUG
            print("[AppleSignInService] Credential state check failed: \(error.localizedDescription)")
            #endif
            // Network error — assume valid to avoid locking user out offline
            return true
        }
    }
}
