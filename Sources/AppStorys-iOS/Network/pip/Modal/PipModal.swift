//
//  PipModal.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.
//

import Foundation

struct PipDetails: Codable {
    let id: String?
    let position: String?
    let smallVideo: String?
    let largeVideo: String?
    let height: Int?
    let width: Int?
    let link: String?
    let campaign: String?
    let buttonText: String?
    let screen: String?

    enum CodingKeys: String, CodingKey {
        case id
        case position
        case smallVideo = "small_video"
        case largeVideo = "large_video"
        case height
        case width
        case link
        case campaign
        case buttonText = "button_text"
        case screen
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        position = try container.decodeIfPresent(String.self, forKey: .position)
        smallVideo = try container.decodeIfPresent(String.self, forKey: .smallVideo)
        largeVideo = try container.decodeIfPresent(String.self, forKey: .largeVideo)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        link = try container.decodeIfPresent(String.self, forKey: .link)
        campaign = try container.decodeIfPresent(String.self, forKey: .campaign)
        buttonText = try container.decodeIfPresent(String.self, forKey: .buttonText)

        if let screenInt = try? container.decode(Int.self, forKey: .screen) {
            screen = String(screenInt)
        } else if let screenString = try? container.decode(String.self, forKey: .screen) {
            screen = screenString
        } else {
            screen = nil
        }
    }
}
