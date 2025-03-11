//
//  File.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 01/03/25.
//

import Foundation

struct Details: Codable {
    let image: String?
    let width: Int?
    let height: Int?
    let link: String?
    let styling: Styling?
    let lottieData: String?
}

struct Styling: Codable {
    let marginBottom: String?
    let topLeftRadius: String?
    let topRightRadius: String?
    let bottomLeftRadius: String?
    let bottomRightRadius: String?
    let enableCloseButton: Bool

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
