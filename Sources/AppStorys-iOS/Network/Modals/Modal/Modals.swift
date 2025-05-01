//
//  Modals.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 22/04/25.
//

import Foundation

struct ModalsDetails: Codable, Identifiable {
    let id: String
    let campaign: String
    let name: String?
    let modals: [Modal]
    let createdAt: String 

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case campaign, name, modals
        case createdAt = "created_at"
    }
}

struct Modal: Codable, Identifiable {
    let id: String
    let mediaType: String
    let size: String
    let link: LinkType
    let borderRadius: String
    let backgroundOpacity: Double
    let url: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case mediaType = "media_type"
        case size, link, borderRadius, backgroundOpacity, url
    }
}
