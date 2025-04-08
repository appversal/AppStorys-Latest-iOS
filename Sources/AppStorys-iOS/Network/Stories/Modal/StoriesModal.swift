//
//  Stories.swift.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 03/04/25.
//


import Foundation
import SwiftUI

struct StoryDetails: Identifiable , Codable {
    let id: String
    let name: String
    let thumbnail: String
    let ringColor: String
    let nameColor: String
    let order: Int
    let slides: [StorySlide]
}

struct StorySlide: Identifiable, Codable {
    let id: String
    let parent: String
    let image: String?
    let video: String?
    let link: String?
    let buttonText: String?
    let order: Int
    
    enum CodingKeys: String, CodingKey {
        case id, parent, image, video, link, order
        case buttonText = "button_text"
    }
}
