//
//  ToolTipModel.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 12/03/25.
//

import Foundation
import SwiftUI

struct TooltipDetails: Codable , Sendable{
    let id: String?
    let campaign: String?
    let name: String?
    let tooltips: [Tooltip]?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case campaign, name, tooltips, createdAt = "created_at"
    }
}

public struct Tooltip: Codable, Sendable {
    let type: String?
    let url: String?
    let link: String?
    let target: String?
    let position: String?
    let order: Int?
    let styling: TooltipStyling?
    let id: String?
    
    enum CodingKeys: String, CodingKey {
        case type, url, link, target, position , order, styling
        case id = "_id"
    }
    public init(type: String?, url: String?, link: String?, target: String?, position: String?, order: Int?, styling: TooltipStyling?, id: String?) {
            self.type = type
            self.url = url
            self.link = link
            self.target = target
            self.position = position
            self.order = order
            self.styling = styling
            self.id = id
        }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        link = try container.decodeIfPresent(String.self, forKey: .link)
        target = try container.decodeIfPresent(String.self, forKey: .target)
        position = try container.decodeIfPresent(String.self, forKey: .position)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        styling = try container.decodeIfPresent(TooltipStyling.self, forKey: .styling)
        if let orderInt = try? container.decode(Int.self, forKey: .order) {
            order = orderInt
        } else if let orderString = try? container.decode(String.self, forKey: .order), let orderInt = Int(orderString) {
            order = orderInt
        } else {
            order = nil
        }
    }
}


public struct TooltipStyling: Codable, Sendable {
    let tooltipDimensions: TooltipDimensions?
    let highlightRadius: String?
    let highlightPadding: String?
    let backgroundColor: String?
    let enableBackdrop: Bool?
    let tooltipArrow: TooltipArrow?
    let spacing: TooltipSpacing?
    let closeButton: Bool?
    
    enum CodingKeys: String, CodingKey {
        case tooltipDimensions, highlightRadius, highlightPadding
        case backgroundColor = "backgroudColor"
        case enableBackdrop, tooltipArrow, spacing, closeButton
    }
    func toColor() -> Color {
            guard let backgroundColor = backgroundColor else { return .white }
            return Color(hex: backgroundColor) ?? .white
        }
}

struct TooltipDimensions: Codable {
    let height: String?
    let width: String?
    let cornerRadius: String?
    
    var widthValue: CGFloat {
            return width?.cgFloatValue ?? 300
        }
    
        var heightValue: CGFloat {
            return height?.cgFloatValue ?? 200
        }
    
        var cornerRadiusValue: CGFloat {
            return cornerRadius?.cgFloatValue ?? 12
        }
}

struct TooltipArrow: Codable {
    let arrowHeight: String?
    let arrowWidth: String?
}

struct TooltipSpacing: Codable {
    let padding: TooltipPadding?
}

struct TooltipPadding: Codable {
    let paddingTop: Int?
    let paddingRight: Int?
    let paddingBottom: Int?
    let paddingLeft: Int?

    enum CodingKeys: String, CodingKey {
        case paddingTop, paddingRight, paddingBottom, paddingLeft
    }
    init(paddingTop: Int?, paddingRight: Int?, paddingBottom: Int?, paddingLeft: Int?) {
            self.paddingTop = paddingTop
            self.paddingRight = paddingRight
            self.paddingBottom = paddingBottom
            self.paddingLeft = paddingLeft
        }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        paddingTop = TooltipPadding.decodeIntOrString(from: container, forKey: .paddingTop)
        paddingRight = TooltipPadding.decodeIntOrString(from: container, forKey: .paddingRight)
        paddingBottom = TooltipPadding.decodeIntOrString(from: container, forKey: .paddingBottom)
        paddingLeft = TooltipPadding.decodeIntOrString(from: container, forKey: .paddingLeft)
    }

    private static func decodeIntOrString(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Int? {
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? container.decode(String.self, forKey: key), let intValue = Int(stringValue) {
            return intValue
        }
        return nil
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

extension String {
    var cgFloatValue: CGFloat? {
        return CGFloat(Int(self) ?? 0)
    }
}

