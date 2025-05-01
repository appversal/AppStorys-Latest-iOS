//
//  BottomSheetModel.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 24/04/25.
//

import SwiftUI

struct BottomSheetDetails: Codable {
    let id: String
    let campaign: String
    let name: String
    let elements: [Element]
    let backgroundColor: String
    let cornerRadius: String
    let enableCrossButton: String
    let triggerType: String
    let selectedEvent: String
    let type: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case campaign, name, elements
        case backgroundColor, cornerRadius
        case enableCrossButton, triggerType, selectedEvent, type
        case createdAt = "created_at"
    }
}

struct Element: Codable, Identifiable {
    let type: ElementType
    let alignment: Alignment
    let order: Int
    let id: String

    let url: String?

    let titleText: String?
    let titleFontStyle: FontStyle?
    let titleFontSize: AnyCodable?
    let descriptionText: String?
    let descriptionFontStyle: FontStyle?
    let descriptionFontSize: AnyCodable?
    let titleLineHeight: Double?
    let descriptionLineHeight: Double?
    let spacingBetweenTitleDesc: Int?
    let bodyBackgroundColor: String?

    let paddingLeft: AnyCodable
    let paddingRight: AnyCodable
    let paddingTop: AnyCodable
    let paddingBottom: AnyCodable

    let ctaText: String?
    let position : String?
    let ctaLink: LinkType?
    let ctaposition: String?
    let ctaBorderRadius: Int?
    let ctaHeight: Int?
    let ctaWidth: Int?
    let ctaTextColour: String?
    let ctaFontSize: AnyCodable?
    let ctaFontFamily: String?
    let ctaFontDecoration: String?
    let ctaBoxColor: String?
    let ctaBackgroundColor: String?
    let ctaFullWidth: Bool?
    
    var paddingLeftValue: CGFloat {
        return Self.extractCGFloat(from: paddingLeft)
    }

    var paddingRightValue: CGFloat {
        return Self.extractCGFloat(from: paddingRight)
    }

    var paddingTopValue: CGFloat {
        return Self.extractCGFloat(from: paddingTop)
    }

    var paddingBottomValue: CGFloat {
        return Self.extractCGFloat(from: paddingBottom)
    }
    
    var titleFontSizeValue: CGFloat? {
        guard let titleFontSize = titleFontSize else { return nil }
        return Self.extractCGFloat(from: titleFontSize)
    }
    
    var descriptionFontSizeValue: CGFloat? {
        guard let descriptionFontSize = descriptionFontSize else { return nil }
        return Self.extractCGFloat(from: descriptionFontSize)
    }
    
    var ctaFontSizeValue: CGFloat? {
        guard let ctaFontSize = ctaFontSize else { return nil }
        return Self.extractCGFloat(from: ctaFontSize)
    }
    
    enum ElementType: String, Codable {
        case image
        case body
        case cta
    }
    
    enum Alignment: String, Codable {
        case left
        case center
        case right
    }
    
    private static func extractCGFloat(from any: AnyCodable) -> CGFloat {
        switch any.value {
        case let intValue as Int:
            return CGFloat(intValue)
        case let doubleValue as Double:
            return CGFloat(doubleValue)
        case let stringValue as String:
            if let number = Double(stringValue) {
                return CGFloat(number)
            }
        default:
            break
        }
        return 0
    }
}

struct FontStyle: Codable {
    let fontFamily: String
    let colour: String
    let decoration: String
}
