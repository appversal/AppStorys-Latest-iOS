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
    public let marginBottom: Int?
    public let marginLeft: Int?
    public let marginRight: Int?
    public let topLeftRadius: Int?
    public let topRightRadius: Int?
    public let bottomLeftRadius: Int?
    public let bottomRightRadius: Int?
    public let enableCloseButton: Bool?
}
