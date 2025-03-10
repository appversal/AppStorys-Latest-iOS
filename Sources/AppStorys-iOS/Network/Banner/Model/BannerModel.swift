//
//  File.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 01/03/25.
//

import Foundation

struct TrackUserResponse: Codable {
    let user_id: String
    let campaigns: [Campaign]
}
struct Campaign: Codable {
    let id: String
    let campaignType: String
    let details: Details?

    enum CodingKeys: String, CodingKey {
        case id
        case campaignType = "campaign_type"
        case details
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        campaignType = try container.decode(String.self, forKey: .campaignType)

        if let singleDetails = try? container.decode(Details.self, forKey: .details) {
            details = singleDetails
        }

        else if let arrayDetails = try? container.decode([Details].self, forKey: .details), let firstDetail = arrayDetails.first {
            details = firstDetail
        }
        else {
            details = nil
        }
    }
}

struct Details: Codable {
    let image: String?
    let width: Int?
    let height: Int?
    let link: String?
}


