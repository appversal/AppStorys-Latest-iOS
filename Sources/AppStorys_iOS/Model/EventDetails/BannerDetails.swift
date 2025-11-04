//
//  BannerDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/10/25.
//


import Foundation

public struct BannerDetails: Codable, Sendable {
    public let id: String?
    public let image: String?
    public let width: Int?
    public let height: Int?
    public let link: String?
    public let styling: BannerStyling?
    
    enum CodingKeys: String, CodingKey {
        case id, image, width, height, link, styling
    }
}

public struct BannerStyling: Codable, Sendable {
    public let marginBottom: String?
    public let marginLeft: String?
    public let marginRight: String?
    public let topLeftRadius: String?
    public let topRightRadius: String?
    public let bottomLeftRadius: String?
    public let bottomRightRadius: String?
    public let enableCloseButton: Bool?
}
