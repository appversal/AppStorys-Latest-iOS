//
//  File.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 01/03/25.

import Foundation

struct BannerDetails: Codable {
    let image: String?
    let width: Double?
    let height: Double?
    let link: LinkType
    let styling: BannerStyling?
    let lottieData: String?
}

enum LinkType: Codable {
    case string(String)
    case dictionary(DeepLinkData)
    
    struct DeepLinkData: Codable {
        let value: String
        let type: String?
        let context: [String: String]?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        }
        else if let dictionaryValue = try? container.decode(DeepLinkData.self) {
            self = .dictionary(dictionaryValue)
        }
        else {
            throw DecodingError.typeMismatch(LinkType.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unexpected format for `link` field"
            ))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        }
    }
}


struct BannerStyling: Codable {
    let marginBottom: String?
    let topLeftRadius: String?
    let topRightRadius: String?
    let bottomLeftRadius: String?
    let bottomRightRadius: String?
    let enableCloseButton: Bool?

    enum CodingKeys: String, CodingKey {
        case marginBottom, topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius, enableCloseButton
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func decodeStringOrNumber(forKey key: CodingKeys) -> String? {
            if let intValue = try? container.decode(Int.self, forKey: key) {
                return String(intValue)
            } else if let doubleValue = try? container.decode(Double.self, forKey: key) {
                return String(doubleValue)
            } else if let stringValue = try? container.decode(String.self, forKey: key) {
                return stringValue
            } else {
                return nil
            }
        }
        marginBottom = decodeStringOrNumber(forKey: .marginBottom)
        topLeftRadius = decodeStringOrNumber(forKey: .topLeftRadius)
        topRightRadius = decodeStringOrNumber(forKey: .topRightRadius)
        bottomLeftRadius = decodeStringOrNumber(forKey: .bottomLeftRadius)
        bottomRightRadius = decodeStringOrNumber(forKey: .bottomRightRadius)
        enableCloseButton = (try? container.decode(Bool.self, forKey: .enableCloseButton)) ?? false
    }
}
