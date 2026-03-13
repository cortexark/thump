// InputValidationTests.swift
// ThumpTests
//
// Unit tests for InputValidation — name validation and DOB validation
// covering boundary conditions, injection patterns, Unicode, and edge cases.

import XCTest
@testable import Thump

final class InputValidationTests: XCTestCase {

    // MARK: - Name Validation: Valid Cases

    func testNameSingleCharacter() {
        let result = InputValidation.validateDisplayName("A")
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.sanitized, "A")
        XCTAssertNil(result.error)
    }

    func testNameNormalName() {
        let result = InputValidation.validateDisplayName("John Smith")
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.sanitized, "John Smith")
    }

    func testNameExactly50Characters() {
        let name = String(repeating: "A", count: 50)
        let result = InputValidation.validateDisplayName(name)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.sanitized.count, 50)
    }

    func testNameWithEmoji() {
        let result = InputValidation.validateDisplayName("John 💪")
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.sanitized, "John 💪")
    }

    func testNameUnicodeGerman() {
        let result = InputValidation.validateDisplayName("Müller")
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.sanitized, "Müller")
    }

    func testNameUnicodeJapanese() {
        let result = InputValidation.validateDisplayName("田中太郎")
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.sanitized, "田中太郎")
    }

    func testNameUnicodeArabic() {
        let result = InputValidation.validateDisplayName("محمد")
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.sanitized, "محمد")
    }

    func testNameWithLeadingTrailingSpaces() {
        let result = InputValidation.validateDisplayName("  Jane Doe  ")
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.sanitized, "Jane Doe")
    }

    func testNameWithNumbers() {
        let result = InputValidation.validateDisplayName("Player123")
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.sanitized, "Player123")
    }

    // MARK: - Name Validation: Invalid Cases

    func testNameEmpty() {
        let result = InputValidation.validateDisplayName("")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Name cannot be empty")
    }

    func testNameWhitespaceOnly() {
        let result = InputValidation.validateDisplayName("   ")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Name cannot be empty")
    }

    func testNameTabsAndNewlines() {
        let result = InputValidation.validateDisplayName("\t\n\r")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Name cannot be empty")
    }

    func testName51Characters() {
        let name = String(repeating: "A", count: 51)
        let result = InputValidation.validateDisplayName(name)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Name must be 50 characters or less")
        XCTAssertEqual(result.sanitized.count, 50)
    }

    func testName1000Characters() {
        let name = String(repeating: "X", count: 1000)
        let result = InputValidation.validateDisplayName(name)
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Name Validation: Injection Patterns

    func testNameXSSInjection() {
        let result = InputValidation.validateDisplayName("<script>alert('xss')</script>")
        // After stripping <>"', should be "scriptalert(xss)/script"
        XCTAssertTrue(result.isValid) // Still has valid chars after stripping
        XCTAssertFalse(result.sanitized.contains("<"))
        XCTAssertFalse(result.sanitized.contains(">"))
        XCTAssertFalse(result.sanitized.contains("\""))
    }

    func testNameSQLInjection() {
        let result = InputValidation.validateDisplayName("'; DROP TABLE users; --")
        XCTAssertFalse(result.sanitized.contains("'"))
        XCTAssertFalse(result.sanitized.contains(";"))
    }

    func testNameOnlyInjectionChars() {
        let result = InputValidation.validateDisplayName("<>\"';\\")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Name contains invalid characters")
    }

    // MARK: - DOB Validation: Valid Cases

    func testDOBExactly13YearsAgo() {
        let dob = Calendar.current.date(byAdding: .year, value: -13, to: Date())!
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.age, 13)
        XCTAssertNil(result.error)
    }

    func testDOB30YearsAgo() {
        let dob = Calendar.current.date(byAdding: .year, value: -30, to: Date())!
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.age, 30)
    }

    func testDOB100YearsAgo() {
        let dob = Calendar.current.date(byAdding: .year, value: -100, to: Date())!
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.age, 100)
    }

    func testDOBExactly150YearsAgo() {
        let dob = Calendar.current.date(byAdding: .year, value: -150, to: Date())!
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.age, 150)
    }

    // MARK: - DOB Validation: Invalid Cases

    func testDOBTomorrow() {
        let dob = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Date cannot be in the future")
    }

    func testDOBToday() {
        let result = InputValidation.validateDateOfBirth(Date())
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Must be at least 13 years old")
    }

    func testDOB12YearsAgo() {
        let dob = Calendar.current.date(byAdding: .year, value: -12, to: Date())!
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Must be at least 13 years old")
    }

    func testDOB5YearsAgo() {
        let dob = Calendar.current.date(byAdding: .year, value: -5, to: Date())!
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Must be at least 13 years old")
        XCTAssertEqual(result.age, 5)
    }

    func testDOB151YearsAgo() {
        let dob = Calendar.current.date(byAdding: .year, value: -151, to: Date())!
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Invalid date of birth")
    }

    func testDOB200YearsAgo() {
        let dob = Calendar.current.date(byAdding: .year, value: -200, to: Date())!
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertFalse(result.isValid)
    }

    func testDOBYear1800() {
        var components = DateComponents()
        components.year = 1800
        components.month = 1
        components.day = 1
        let dob = Calendar.current.date(from: components)!
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Invalid date of birth")
    }

    // MARK: - DOB Validation: Boundary Cases

    func testDOBAlmostFuture() {
        // 1 second ago — should be valid age-wise but too young
        let dob = Date(timeIntervalSinceNow: -1)
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertFalse(result.isValid) // age < 13
    }

    func testDOBExactly13YearsMinusOneDay() {
        var components = DateComponents()
        components.year = -13
        components.day = 1
        let dob = Calendar.current.date(byAdding: components, to: Date())!
        let result = InputValidation.validateDateOfBirth(dob)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, "Must be at least 13 years old")
    }
}
