//
//  File.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 01/03/25.
//

import Foundation

struct TrackUserResponsePip: Codable {
    let user_id: String
    let campaigns: [PipCampaign]
}

struct PipCampaign: Codable {
    let id: String
    let campaignType: String
    let details: [DetailsPip]? 
    let position: String?

    enum CodingKeys: String, CodingKey {
        case id
        case campaignType = "campaign_type"
        case details
        case position
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        campaignType = try container.decode(String.self, forKey: .campaignType)
        position = try container.decodeIfPresent(String.self, forKey: .position)

        // ✅ Handle `details` as Dictionary OR Array
        if let detailsDict = try? container.decode(DetailsPip.self, forKey: .details) {
            details = [detailsDict] // Convert single dictionary to array
        } else if let detailsArray = try? container.decode([DetailsPip].self, forKey: .details) {
            details = detailsArray // Use array as-is
        } else {
            details = nil // Default to nil if neither format works
        }
    }
}

// MARK: - PIP Campaign Details
struct DetailsPip: Codable {
    let id: String?
    let position: String?
    let smallVideo: String?
    let largeVideo: String?
    let height: Int?
    let width: Int?
    let link: String?
    let campaign: String?
    let buttonText: String?
    let screen: String?  // Change screen to String to handle both cases

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

    // Custom decoding to handle both Int and String for `screen`
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

        // Decode screen as either Int or String, always storing it as a String
        if let screenInt = try? container.decode(Int.self, forKey: .screen) {
            screen = String(screenInt)
        } else if let screenString = try? container.decode(String.self, forKey: .screen) {
            screen = screenString
        } else {
            screen = nil
        }
    }
}
