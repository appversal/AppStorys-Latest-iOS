//
//  AccessTokenResponse.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 07/10/25.
//

import Foundation

// MARK: - Access Token Response
public struct AccessTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

// MARK: - WebSocket Connection Response
public struct WebSocketConnectionResponse: Codable, Sendable {
    let userID: String
    let ws: WebSocketConfig
    let screenCaptureEnabled: Bool?
    
    enum CodingKeys: String, CodingKey {
        case userID = "userID"
        case ws
        case screenCaptureEnabled = "screen_capture_enabled"
    }
}

public struct WebSocketConfig: Codable, Sendable {
    let expires: Int
    let sessionID: String
    let token: String
    let url: String
}

// MARK: - Campaign Response
public struct CampaignResponse: Codable, Sendable {
    let userId: String?
    let messageId: String?
    let campaigns: [CampaignModel]?
    let metadata: Metadata?
    let sentAt: Int?
    let testUser: Bool?

    enum CodingKeys: String, CodingKey {
        case userId
        case messageId = "message_id"
        case campaigns, metadata
        case sentAt = "sent_at"
        case testUser = "test_user"
    }
}

public struct Metadata: Codable, Sendable {
    let screenCaptureEnabled: Bool?
    let testUser: Bool?

    enum CodingKeys: String, CodingKey {
        case screenCaptureEnabled = "screen_capture_enabled"
        case testUser = "test_user"
    }
}

// MARK: - Campaign Model
public struct CampaignModel: Codable, Sendable {
    public let id: String
    public let campaignType: String
    public let clientId: String
    public let position: String?
    public let details: CampaignDetails
    public let screen: String?
    public let displayTrigger: Bool?
    public let triggerEvent: String?
    public let isAll: Bool?
    public let isTesting: Bool?
    public let priority: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case campaignType = "campaign_type"
        case clientId = "client_id"
        case position, details, screen
        case displayTrigger = "display_trigger"
        case triggerEvent = "trigger_event"
        case isAll, isTesting, priority
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        campaignType = try container.decode(String.self, forKey: .campaignType)
        clientId = try container.decode(String.self, forKey: .clientId)
        position = try container.decodeIfPresent(String.self, forKey: .position)
        screen = try container.decodeIfPresent(String.self, forKey: .screen)
        displayTrigger = try container.decodeIfPresent(Bool.self, forKey: .displayTrigger)
        triggerEvent = try container.decodeIfPresent(String.self, forKey: .triggerEvent)
        isAll = try container.decodeIfPresent(Bool.self, forKey: .isAll)
        isTesting = try container.decodeIfPresent(Bool.self, forKey: .isTesting)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        
        // Decode details based on campaign type
        switch campaignType {
        case "PIP":
            let pipDetails = try container.decode(PipDetails.self, forKey: .details)
            details = .pip(pipDetails)
            Logger.debug("✅ Decoded PIP campaign")
        case "BAN":
            let bannerDetails = try container.decode(BannerDetails.self, forKey: .details)
            details = .banner(bannerDetails)
        case "FLT":
            let floaterDetails = try container.decode(FloaterDetails.self, forKey: .details)
            details = .floater(floaterDetails)
        case "CSAT":
            let csatDetails = try container.decode(CsatDetails.self, forKey: .details)
            details = .csat(csatDetails)
        case "SUR":
            let surveyDetails = try container.decode(SurveyDetails.self, forKey: .details)
            details = .survey(surveyDetails)
        case "BTS":
            let btsDetails = try container.decode(BottomSheetDetails.self, forKey: .details)
            details = .bottomSheet(btsDetails)
            
        case "WID":
            let widgetDetails = try container.decode(WidgetDetails.self, forKey: .details)
            details = .widget(widgetDetails)
            Logger.debug("✅ Decoded WID campaign with \(widgetDetails.widgetImages?.count ?? 0) images")
            
            // ✅ ADD THIS CASE for Stories
        case "STR":
            let storyDetails = try container.decode([StoryDetails].self, forKey: .details)
            details = .stories(storyDetails)
            Logger.debug("✅ Decoded STR campaign with \(storyDetails.count) stories")
            
            // ✅ ADD THIS CASE for Modals
        case "MOD":
            let modalDetails = try container.decode(ModalDetails.self, forKey: .details)
            details = .modal(modalDetails)
            Logger.debug("✅ Decoded MOD campaign")
        default:
            Logger.warning("⚠️ Unknown campaign type: \(campaignType)")
            details = .unknown
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(campaignType, forKey: .campaignType)
        try container.encode(clientId, forKey: .clientId)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encodeIfPresent(screen, forKey: .screen)
        try container.encodeIfPresent(displayTrigger, forKey: .displayTrigger)
        try container.encodeIfPresent(triggerEvent, forKey: .triggerEvent)
        try container.encodeIfPresent(isAll, forKey: .isAll)
        try container.encodeIfPresent(isTesting, forKey: .isTesting)
        try container.encodeIfPresent(priority, forKey: .priority)
        
        // Encode details
        switch details {
        case .pip(let pipDetails):
            try container.encode(pipDetails, forKey: .details)
        case .banner(let bannerDetails):
            try container.encode(bannerDetails, forKey: .details)
        case .floater(let floaterDetails):
            try container.encode(floaterDetails, forKey: .details)
        case .csat(let csatDetails):
            try container.encode(csatDetails, forKey: .details)
        case .survey(let surveyDetails):
            try container.encode(surveyDetails, forKey: .details)
        case .bottomSheet(let btsDetails):
            try container.encode(btsDetails, forKey: .details)
        case .widget(let widgetDetails):
            try container.encode(widgetDetails, forKey: .details)
        case .tooltip(let tooltipDetails):
            try container.encode(tooltipDetails, forKey: .details)
        case .modal(let modalDetails):
            try container.encode(modalDetails, forKey: .details)
        case .stories(let storyDetails):
            try container.encode(storyDetails, forKey: .details)
        case .reel(let reelDetails):
            try container.encode(reelDetails, forKey: .details)
        case .unknown:
            break
        }
    }
}

// MARK: - Campaign Details Enum
public enum CampaignDetails: Sendable {
    case banner(BannerDetails)
    case floater(FloaterDetails)
    case pip(PipDetails)
    case csat(CsatDetails)
    case survey(SurveyDetails)
    case widget(WidgetDetails)
    case bottomSheet(BottomSheetDetails)
    case tooltip(TooltipDetails)
    case modal(ModalDetails)
    case stories([StoryDetails])
    case reel(ReelDetails)
    case unknown
}
