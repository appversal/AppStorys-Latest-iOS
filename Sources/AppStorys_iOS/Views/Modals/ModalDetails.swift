//
//  ModalDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//

import Foundation

// MARK: - Modal Details

public struct ModalDetails: Codable, Sendable {
    let id: String?
    let modals: [ModalItem]
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case id, modals, name
    }
}

// MARK: - Modal Item

public struct ModalItem: Codable, Sendable, Identifiable {
    public var id: String { name } // Use name as unique identifier
    
    let backgroundOpacity: String?
    let borderRadius: String?
    let link: String?
    let name: String
    let redirection: RedirectionConfig?
    let size: String?
    let url: String?
    
    enum CodingKeys: String, CodingKey {
        case backgroundOpacity, borderRadius, link, name
        case redirection, size, url
    }
    
    // MARK: - Computed Properties
    
    var backdropOpacity: Double {
        guard let opacityString = backgroundOpacity,
              let opacity = Double(opacityString) else {
            return 0.5 // Default backdrop opacity
        }
        return max(0.0, min(1.0, opacity))
    }
    
    var cornerRadius: CGFloat {
        guard let radiusString = borderRadius,
              let radius = Double(radiusString) else {
            return 24 // Default corner radius
        }
        return CGFloat(radius)
    }
    
    var modalSize: CGFloat {
        guard let sizeString = size,
              let sizeValue = Double(sizeString) else {
            return 300 // Default size
        }
        return CGFloat(sizeValue)
    }
    
    var imageURL: URL? {
        guard let urlString = url else { return nil }
        return URL(string: URLHelper.sanitizeURL(urlString) ?? urlString)
    }
    
    var destinationURL: URL? {
        // Priority: redirection.url > link
        if let redirectionURL = redirection?.url, !redirectionURL.isEmpty {
            return URL(string: redirectionURL)
        }
        
        if let linkURL = link, !linkURL.isEmpty {
            return URL(string: linkURL)
        }
        
        return nil
    }
}

// MARK: - Redirection Config

public struct RedirectionConfig: Codable, Sendable {
    let key: String?
    let pageName: String?
    let type: String?
    let url: String?
    let value: String?
    
    enum CodingKeys: String, CodingKey {
        case key, pageName, type, url, value
    }
}
