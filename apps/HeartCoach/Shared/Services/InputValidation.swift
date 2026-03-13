// InputValidation.swift
// ThumpCore
//
// Input validation for user-entered data (names, dates of birth, etc.)
// Provides sanitization, boundary checking, and error messages.
// Used by OnboardingView and SettingsView to prevent invalid data entry.
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - Input Validation

/// Centralised input validation for user-entered data.
///
/// All methods are static and pure — no side effects, no state.
/// ```swift
/// let result = InputValidation.validateDisplayName("John 💪")
/// // result.isValid == true, result.sanitized == "John 💪"
///
/// let dobResult = InputValidation.validateDateOfBirth(futureDate)
/// // dobResult.isValid == false, dobResult.error == "Date cannot be in the future"
/// ```
public struct InputValidation {

    // MARK: - Name Validation

    /// Result of a display name validation.
    public struct NameResult {
        /// Whether the input is valid after sanitization.
        public let isValid: Bool
        /// The cleaned-up version of the input (trimmed, injection patterns removed).
        public let sanitized: String
        /// Human-readable error message if invalid, nil if valid.
        public let error: String?
    }

    /// Maximum allowed length for display names.
    public static let maxNameLength = 50

    /// Validates and sanitises a user display name.
    ///
    /// Rules:
    /// - Empty or whitespace-only → invalid
    /// - Over 50 characters → invalid
    /// - HTML/SQL injection characters (`<`, `>`, `"`, `'`, `;`, `\`) → stripped
    /// - Unicode, emoji → allowed
    ///
    /// - Parameter input: The raw user-entered name string.
    /// - Returns: A `NameResult` with validation status, sanitised string, and optional error.
    public static func validateDisplayName(_ input: String) -> NameResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty check
        if trimmed.isEmpty {
            return NameResult(isValid: false, sanitized: "", error: "Name cannot be empty")
        }

        // Length check
        if trimmed.count > maxNameLength {
            return NameResult(
                isValid: false,
                sanitized: String(trimmed.prefix(maxNameLength)),
                error: "Name must be \(maxNameLength) characters or less"
            )
        }

        // Strip injection characters
        let sanitized = trimmed.replacingOccurrences(
            of: "[<>\"';\\\\]",
            with: "",
            options: .regularExpression
        )

        // If sanitization removed everything, it's invalid
        if sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return NameResult(isValid: false, sanitized: "", error: "Name contains invalid characters")
        }

        return NameResult(isValid: true, sanitized: sanitized, error: nil)
    }

    // MARK: - Date of Birth Validation

    /// Result of a date-of-birth validation.
    public struct DOBResult {
        /// Whether the date is a valid date of birth.
        public let isValid: Bool
        /// Human-readable error message if invalid, nil if valid.
        public let error: String?
        /// The user's age in years (if valid), nil otherwise.
        public let age: Int?
    }

    /// Minimum allowed age (inclusive).
    public static let minimumAge = 13

    /// Maximum allowed age (inclusive).
    public static let maximumAge = 150

    /// Validates a date of birth.
    ///
    /// Rules:
    /// - Future dates → invalid
    /// - Age < 13 → invalid
    /// - Age > 150 → invalid
    ///
    /// - Parameter date: The user-selected date of birth.
    /// - Returns: A `DOBResult` with validation status, optional error, and computed age.
    public static func validateDateOfBirth(_ date: Date) -> DOBResult {
        let calendar = Calendar.current
        let now = Date()

        // Future date check
        if date > now {
            return DOBResult(isValid: false, error: "Date cannot be in the future", age: nil)
        }

        // Compute age
        let components = calendar.dateComponents([.year], from: date, to: now)
        let age = components.year ?? 0

        // Minimum age
        if age < minimumAge {
            return DOBResult(
                isValid: false,
                error: "Must be at least \(minimumAge) years old",
                age: age
            )
        }

        // Maximum age
        if age > maximumAge {
            return DOBResult(
                isValid: false,
                error: "Invalid date of birth",
                age: age
            )
        }

        return DOBResult(isValid: true, error: nil, age: age)
    }

    // MARK: - Private

    private init() {}
}
