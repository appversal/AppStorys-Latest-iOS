//
//  ReelsModal.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 01/04/25.
//

import Foundation

struct ReelsDetails: Codable {
    let id: String
    let reels: [Reel]
    let styling: ReelsStyling
}


struct Reel: Codable {
    let id: String
    let buttonText: String
    let order: Int
    let descriptionText: String
    let video: String
    let likes: Int
    let thumbnail: String
    let link: String
    let styling: BannerStyling?

    enum CodingKeys: String, CodingKey {
        case id
        case buttonText = "button_text"
        case order
        case descriptionText = "description_text"
        case video
        case likes
        case thumbnail
        case link
        case styling
    }
}

struct ReelsStyling: Codable {
    let ctaBoxColor: String
    let cornerRadius: String
    let ctaTextColor: String
    let thumbnailWidth: String
    let likeButtonColor: String
    let thumbnailHeight: String
    let descriptionTextColor: String
}

