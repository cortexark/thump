// ConnectivityMessageCodec.swift
// ThumpCore
//
// Shared WatchConnectivity payload codec used by both iOS and watchOS.
// Ensures payloads remain property-list compliant by encoding JSON payloads
// as Base-64 strings inside the message dictionary.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Connectivity Message Type

public enum ConnectivityMessageType: String, Sendable {
    case assessment
    case feedback
    case requestAssessment
    case actionPlan
    case error
    case acknowledgement
}

// MARK: - Connectivity Message Codec

public enum ConnectivityMessageCodec {

    public static func encode<T: Encodable>(
        _ payload: T,
        type: ConnectivityMessageType
    ) -> [String: Any]? {
        do {
            let data = try encoder.encode(payload)
            return [
                "type": type.rawValue,
                "payload": data.base64EncodedString()
            ]
        } catch {
            debugPrint("[ConnectivityMessageCodec] Encode failed for \(T.self): \(error.localizedDescription)")
            return nil
        }
    }

    public static func decode<T: Decodable>(
        _ type: T.Type,
        from message: [String: Any],
        payloadKeys: [String] = ["payload"]
    ) -> T? {
        for key in payloadKeys {
            guard let value = message[key] else { continue }
            if let decoded: T = decode(type, fromPayloadValue: value) {
                return decoded
            }
        }
        return nil
    }

    public static func errorMessage(_ reason: String) -> [String: Any] {
        [
            "type": ConnectivityMessageType.error.rawValue,
            "reason": reason
        ]
    }

    public static func acknowledgement() -> [String: Any] {
        [
            "type": ConnectivityMessageType.acknowledgement.rawValue,
            "status": "received"
        ]
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        fromPayloadValue value: Any
    ) -> T? {
        if let base64 = value as? String,
           let data = Data(base64Encoded: base64) {
            return try? decoder.decode(type, from: data)
        }

        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value) {
            return try? decoder.decode(type, from: data)
        }

        return nil
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
