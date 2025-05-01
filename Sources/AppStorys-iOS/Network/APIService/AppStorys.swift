//
//  File.swift
//  AppStorys-iOS-main-3
//
//  Created by Darshika Gupta on 28/02/25.
//

import SwiftUI
import Foundation

public class DeepLinkManager {
    @MainActor public static let shared = DeepLinkManager()
    public var navigateToScreen: ((String, [String: String]?) -> Void)?
}

@MainActor
public class AppStorys: ObservableObject {
    private let session: URLSession
    var testSession: URLSession {
        return session
    }
    
    @Published var accessToken: String? = nil
    @Published var campaigns: [String] = []
    @Published var widgetCampaigns: [CampaignModel] = []
    @Published var banCampaigns: [CampaignModel] = []
    @Published var csatCampaigns: [CampaignModel] = []
    @Published var pipCampaigns: [CampaignModel] = []
    @Published var toolTipCampaigns: [CampaignModel] = []
    @Published var floaterCampaigns: [CampaignModel] = []
    @Published var surveyCampaigns: [CampaignModel] = []
    @Published var storiesCampaigns: [CampaignModel] = []
    @Published var reelsCampaigns: [CampaignModel] = []
    @Published var bottomSheetsCampaigns: [CampaignModel] = []
    @Published var modalsCampaigns: [CampaignModel] = []
    
    public init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }
    
    public enum Endpoints: String {
        case validateAccount = "/validate-account/"
        case trackScreen = "/track-screen/"
        case trackUser = "/track-user/"
        case trackAction = "/track-action/"
    }
    
    public func appstorys(appID: String, accountID: String, userID: String) async {
        KeychainHelper.shared.save(userID, key: "userIDAppStorys")
        await validateAccount(appID: appID, accountID: accountID)
    }

    public func validateAccount(appID: String, accountID: String) async {
        let url = URL(string: "https://backend.appstorys.com/api/v1/users\(Endpoints.validateAccount.rawValue)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "app_id": appID,
            "account_id": accountID
        ]
        request.httpBody = try? JSONEncoder().encode(body)
        do {
            let (data, _) = try await session.data(for: request)
            let decodedResponse = try JSONDecoder().decode(ValidateAccountResponse.self, from: data)
            
            DispatchQueue.main.async {
                self.accessToken = decodedResponse.access_token
                KeychainHelper.shared.save(decodedResponse.access_token, key: "accessTokenAppStorys")
                KeychainHelper.shared.save(decodedResponse.refresh_token, key: "refreshTokenAppStorys")
            }
        } catch {
        }
    }
    
    public func trackScreen(screenName: String, positions: [String]? = nil, elementLists: [String]? = nil) async {
        var accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys")
        for _ in 0..<5 {
            if accessToken != nil { break }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys")
        }
        
        guard let accessToken else {
            return
        }
        
        let url = URL(string: "https://backend.appstorys.com/api/v1/users\(Endpoints.trackScreen.rawValue)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = ["screen_name": screenName]
        if let positions, !positions.isEmpty {
            body["position_list"] = positions
            body["element_list"] = elementLists
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        do {
            let (data, response) = try await session.data(for: request)
            let jsonString = String(data: data, encoding: .utf8)
            
            let decodedResponse = try JSONDecoder().decode(TrackScreenResponse.self, from: data)
            let campaigns = decodedResponse.campaigns ?? []
            await trackUser(campaigns: campaigns, attributes: nil)
        } catch {
        }
    }
    
    public func trackUser(campaigns: [String], attributes: [[String: Any]]?) async {
        guard let userID = KeychainHelper.shared.get(key: "userIDAppStorys"),
              let accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys") else {
            return
        }
        let url = URL(string: "https://backend.appstorys.com/api/v1/users\(Endpoints.trackUser.rawValue)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "user_id": userID,
            "campaign_list": campaigns,
            "attributes": attributes ?? []
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        do {
            let (data, response) = try await session.data(for: request)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            let decodedResponse = try JSONDecoder().decode(TrackUserResponseTwo.self, from: data)
            
            DispatchQueue.main.async {
                self.banCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "BAN" }
                self.widgetCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "WID" }
                self.csatCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "CSAT" }
                self.pipCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "PIP" }
                self.toolTipCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "TTP" }
                self.floaterCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "FLT" }
                self.surveyCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "SUR" }
                self.storiesCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "STR" }
                self.reelsCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "REL" }
                self.bottomSheetsCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "BTS" }
                self.modalsCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "MOD" }
                print(self.modalsCampaigns)
            }
        }
        catch {
        }
    }
    
    func clickEvent(link: LinkType?, campaignId: String, widgetImageId: String? = nil) {
        guard let link = link else {
            return
        }
        switch link {
        case .string(let url):
            if isValidUrl(url) {
                openUrl(url)
            } else if let navigate = DeepLinkManager.shared.navigateToScreen {
                navigate(url, nil)
            } else {
            }
        case .dictionary(let deepLinkData):
            handleDeepLink(data: deepLinkData, campaignId: campaignId, widgetImageId: widgetImageId)
        case .none:
            return
        }
    }
    
    func handleDeepLink(data: LinkType.DeepLinkData, campaignId: String, widgetImageId: String?) {
        if let navigate = DeepLinkManager.shared.navigateToScreen {
            navigate(data.value, data.context)
        } else {
        }
    }
    func isValidUrl(_ url: String?) -> Bool {
        guard let urlString = url, let url = URL(string: urlString) else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }
    
    func openUrl(_ url: String) {
        guard let url = URL(string: url) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func trackAction(type: ActionType, campaignID: String, widgetID: String? = nil, storySlide: String? = nil, reelId: String? = nil) async {
        guard let accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys") , !accessToken.isEmpty else {
            return
        }
        
        guard let userID = KeychainHelper.shared.get(key: "userIDAppStorys"), !userID.isEmpty else {
            return
        }
        
        guard !campaignID.isEmpty else {
            return
        }
        
        let url = URL(string: "https://backend.appstorys.com/api/v1/users\(Endpoints.trackAction.rawValue)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "event_type": type.rawValue,
            "campaign_id": campaignID,
            "user_id": userID
        ]
        
        if let widgetID = widgetID {
            body["widget_image"] = widgetID
        }
        
        if let storySlide = storySlide {
            body["story_slide"] = storySlide
        }
        if let reelId = reelId {
            body["reel_id"] = reelId
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                } else {
                }
            }
        } catch {
        }
    }
    
    
    func isTokenExpired(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return true }
        let payloadData = Data(base64Encoded: String(parts[1]).padding(toLength: ((parts[1].count+3)/4)*4, withPad: "=", startingAt: 0))
        guard let data = payloadData,
              let payload = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            return true
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        return expirationDate <= Date()
    }
    
    public func trackEvents(eventType: String, campaignId: String? = nil, metadata: [String: Any]? = nil) {
        guard let accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys") else {
            return
        }
        guard let userID = KeychainHelper.shared.get(key: "userIDAppStorys") else {
            return
        }
        
        var requestBody: [String: Any] = [
            "user_id": userID,
            "event": eventType
        ]
        
        if let campaignId = campaignId {
            requestBody["campaign_id"] = campaignId
        }
        
        if let metadata = metadata {
            requestBody["metadata"] = metadata
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            
            var request = URLRequest(url: URL(string: "https://tracking.appstorys.com/capture-event")!)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let task = session.dataTask(with: request) { data, response, error in
                if error != nil {
                    return
                }
                if response is HTTPURLResponse {
                }
                
                if let data = data, let _ = String(data: data, encoding: .utf8) {
                }
            }
            task.resume()
        } catch {
        }
    }
    
    struct AnalyticsEvent: Codable {
        let StorySlide_id: String
        let AppUser_id: String
        let event_type: String
    }
    
    
    struct TrackUserRequest: Codable {
        let user_id: String
        let campaign_list: [String]
        let attributes: [[String: AnyCodable]]?
        
    }
    struct TrackActionRequest: Codable {
        let campaign_id: String
        let user_id: String
        let event_type: String
        let widget_id: String?
    }
    
    private struct TrackScreenRequest: Codable {
        let screen_name: String
        let position_list: [String]
    }
}


enum APIError: Error {
    case noAccessToken
    case invalidResponse
    case invalidURL
}

enum ActionType: String {
    case view = "IMP"
    case click = "CLK"
}

struct TrackUserResponseTwo: Codable {
    let userID: String
    let campaigns: [CampaignModel]
    
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case campaigns
    }
}
struct CampaignModel: Codable , Equatable {
    let id: String
    let campaignType: String
    let position: String?
    let details: CampaignDetailsTwo
    
    static func == (lhs: CampaignModel, rhs: CampaignModel) -> Bool {
        return lhs.id == rhs.id &&
        lhs.campaignType == rhs.campaignType &&
        lhs.position == rhs.position
    }
    enum CodingKeys: String, CodingKey {
        case id
        case campaignType = "campaign_type"
        case position
        case details
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.campaignType = try container.decode(String.self, forKey: .campaignType)
        self.position = try container.decodeIfPresent(String.self, forKey: .position)
        
        
        switch campaignType {
        case "BAN":
            self.details = .banner(try container.decode(BannerDetails.self, forKey: .details))
        case "WID":
            self.details = .widget(try container.decode(WidgetDetails.self, forKey: .details))
        case "CSAT":
            if let csatDetails = try? container.decode(CsatDetails.self, forKey: .details) {
                self.details = .csat(csatDetails)
            } else {
                self.details = .unknown
            }
        case "PIP":
            if let pipDetails = try? container.decode(PipDetails.self, forKey: .details) {
                self.details = .pip(pipDetails)
            } else {
                self.details = .unknown
            }
        case "FLT":
            if let floaterDetails = try? container.decode(FloaterDetails.self, forKey: .details) {
                self.details = .floater(floaterDetails)
            } else {
                self.details = .unknown
            }
        case "SUR":
            if let surveyDetails = try? container.decode(SurveyDetails.self, forKey: .details) {
                self.details = .survey(surveyDetails)
            } else {
                self.details = .unknown
            }
        case "STR":
            do {
                let storyDetails = try container.decode([StoryDetails].self, forKey: .details)
                self.details = .stories(storyDetails)
            } catch {
                self.details = .unknown
            }
        case "REL":
            do {
                let reelDetails = try container.decode(ReelsDetails.self, forKey: .details)
                self.details = .reel(reelDetails)
            } catch {
                self.details = .unknown
            }
        case "BTS":
            if let bottomSheetDetails = try? container.decode(BottomSheetDetails.self, forKey: .details) {
                self.details = .bottomSheets(bottomSheetDetails)
            } else {
                self.details = .unknown
            }
        case "MOD":
            do {
                let csatDetails = try container.decode(ModalsDetails.self, forKey: .details)
                self.details = .modals(csatDetails)
                      } catch {
                          print("Failed to decode CsatDetails: \(error)")
                          self.details = .unknown
                      }
        case "TTP":
            self.details = .toolTip(try container.decode(TooltipDetails.self, forKey: .details))
        default:
            self.details = .unknown
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(campaignType, forKey: .campaignType)
        try container.encodeIfPresent(position, forKey: .position)
        
        switch details {
        case .banner(let bannerDetails):
            try container.encode(bannerDetails, forKey: .details)
        case .widget(let widgetDetails):
            try container.encode(widgetDetails, forKey: .details)
        case .csat(let csatDetails):
            try container.encode(csatDetails, forKey: .details)
        case .pip(let pipDetails):
            try container.encode(pipDetails, forKey: .details)
        case .toolTip(let toolTipDetails):
            try container.encode(toolTipDetails, forKey: .details)
        case .floater(let floaterDetails):
            try container.encode(floaterDetails, forKey: .details)
        case .survey(let surveyDetails):
            try container.encode(surveyDetails, forKey: .details)
        case .stories(let storiesDetails):
            try container.encode(storiesDetails, forKey: .details)
        case .reel(let reelDetails):
            try container.encode(reelDetails, forKey: .details)
        case .bottomSheets(let bottomSheetDetails):
            try container.encode(bottomSheetDetails, forKey: .details)
        case .modals(let modalsDetails):
            try container.encode(modalsDetails, forKey: .details)
        case .unknown:
            break
        }
    }
}

enum CampaignDetailsTwo {
    case banner(BannerDetails)
    case widget(WidgetDetails)
    case csat(CsatDetails)
    case pip(PipDetails)
    case toolTip(TooltipDetails)
    case floater(FloaterDetails)
    case survey(SurveyDetails)
    case stories([StoryDetails])
    case reel(ReelsDetails)
    case bottomSheets(BottomSheetDetails)
    case modals(ModalsDetails)
    case unknown
    
    var widgetType: String? {
        if case let .widget(widgetDetails) = self {
            return widgetDetails.type
        }
        return nil
    }
}
struct ValidateAccountResponse: Codable {
    let access_token: String
    let refresh_token: String
}

struct TrackScreenResponse: Codable {
    let campaigns: [String]
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            self.value = arrayValue
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            self.value = dictValue
        } else {
            throw DecodingError.typeMismatch(Any.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let value as Bool:
            try container.encode(value)
        case let value as Int:
            try container.encode(value)
        case let value as Double:
            try container.encode(value)
        case let value as String:
            try container.encode(value)
        case let value as [AnyCodable]:
            try container.encode(value)
        case let value as [String: AnyCodable]:
            try container.encode(value)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Unsupported type"))
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
