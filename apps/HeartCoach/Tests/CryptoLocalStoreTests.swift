// CryptoLocalStoreTests.swift
// ThumpCoreTests
//
// CryptoService encryption coverage.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import Thump

final class CryptoServiceTests: XCTestCase {

    override func tearDown() {
        try? CryptoService.deleteKey()
        super.tearDown()
    }

    func testEncryptDecryptRoundTrip() throws {
        let original = Data("Hello, Thump!".utf8)
        let encrypted = try CryptoService.encrypt(original)
        let decrypted = try CryptoService.decrypt(encrypted)
        XCTAssertEqual(decrypted, original)
    }

    func testEncryptProducesDifferentCiphertexts() throws {
        let data = Data("Deterministic input".utf8)
        let encrypted1 = try CryptoService.encrypt(data)
        let encrypted2 = try CryptoService.encrypt(data)
        XCTAssertNotEqual(encrypted1, encrypted2)
    }

    func testTamperedCiphertextFailsDecryption() throws {
        var encrypted = try CryptoService.encrypt(Data("Sensitive".utf8))
        encrypted[encrypted.count / 2] ^= 0xFF

        XCTAssertThrowsError(try CryptoService.decrypt(encrypted))
    }
}
