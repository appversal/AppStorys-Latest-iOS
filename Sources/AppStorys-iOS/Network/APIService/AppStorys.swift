//
//  File.swift
//  AppStorys-iOS-main-3
//
//  Created by Darshika Gupta on 28/02/25.
//

import SwiftUI
import Foundation

@MainActor
public class AppStorys: ObservableObject {
    
    private let session: URLSession

    var testSession: URLSession {
        return session
    }

    @Published var accessToken: String? = nil
    @Published var campaigns: [String] = []
    @Published var widgetCampaigns: [CampaignTwo] = []
    @Published var banCampaigns: [CampaignTwo] = []
    @Published var csatCampaigns: [CampaignTwo] = []
    @Published var pipCampaigns: [CampaignTwo] = []
    
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
            UserDefaults.standard.set(userID, forKey: "userID")
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
                    UserDefaults.standard.set(decodedResponse.access_token, forKey: "accessTokenAppStorys")
                    UserDefaults.standard.set(decodedResponse.refresh_token, forKey: "refreshToken")
                }
            } catch {
               
            }
        }

    public func trackScreen(screenName: String, positions: [String]? = nil) async {
        var accessToken = UserDefaults.standard.string(forKey: "accessTokenAppStorys")

        for _ in 0..<5 {
                if accessToken != nil { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                accessToken = UserDefaults.standard.string(forKey: "accessTokenAppStorys")
            }

            guard let accessToken else {
                return
            }


        let url = URL(string: "https://backend.appstorys.com/api/v1/users/track-screen/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = ["screen_name": screenName]
        if let positions, !positions.isEmpty {
            body["position_list"] = positions
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        do {
            let (data, _) = try await session.data(for: request)

            if let jsonString = String(data: data, encoding: .utf8) {
            }

            let decodedResponse = try JSONDecoder().decode(TrackScreenResponse.self, from: data)
            let campaigns = decodedResponse.campaigns ?? []

            await trackUser(campaigns: campaigns, attributes: nil)
        } catch {
        }

    }


    public func trackUser(campaigns: [String], attributes: [[String: Any]]?) async {
        guard let userID = UserDefaults.standard.string(forKey: "userID"),
              let accessToken = UserDefaults.standard.string(forKey: "accessTokenAppStorys") else {
            return
        }

        let url = URL(string: "https://backend.appstorys.com/api/v1/users/track-user/")!
        
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
            let (data, _) = try await session.data(for: request)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                   }
            
            let decodedResponse = try JSONDecoder().decode(TrackUserResponseTwo.self, from: data)
            DispatchQueue.main.async {
                self.banCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "BAN" }
                self.widgetCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "WID" }
                self.csatCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "CSAT" }
                self.pipCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "PIP" }
            }
        } catch {
        }
    }
    
    func trackAction(type: ActionType, campaignID: String, widgetID : String?) async {
        guard let accessToken = UserDefaults.standard.string(forKey: "accessTokenAppStorys") else {
            return
        }

        guard !campaignID.isEmpty else {
            return
        }

        guard let userID = UserDefaults.standard.string(forKey: "userID") else {
            return
        }

        let url = URL(string: "https://backend.appstorys.com/api/v1/users/track-action/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "event_type": type.rawValue,
            "campaign_id": campaignID,
            "user_id": userID,
            "widget_image" : widgetID
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted) else {
            return
        }
        request.httpBody = jsonData
        if let jsonString = String(data: jsonData, encoding: .utf8) {
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }

            if httpResponse.statusCode == 401 {
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
        guard let accessToken = UserDefaults.standard.string(forKey: "accessTokenAppStorys") else {
            return
        }
        guard let userID = UserDefaults.standard.string(forKey: "userID") else {
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
                    if let error = error {
                        return
                    }
                    if let response = response as? HTTPURLResponse {
                    }
                }
                task.resume()
            } catch {
            }
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

// Root Response Model
struct TrackUserResponseTwo: Codable {
    let userID: String
    let campaigns: [CampaignTwo]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case campaigns
    }
}
// Generic Campaign Model
struct CampaignTwo: Codable {
    let id: String
    let campaignType: String
    let position: String?
    let details: CampaignDetailsTwo
    
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
            self.details = .banner(try container.decode(Details.self, forKey: .details))
        case "WID":
            self.details = .widget(try container.decode(CampaignDetailsForWidget.self, forKey: .details))
        case "CSAT":
            if let csatDetails = try? container.decode(DetailsCSAT.self, forKey: .details) {
                self.details = .csat(csatDetails)
            } else {
                self.details = .unknown
            }
//        case "PIP":
//            if let pipDetails = try? container.decode(DetailsPip.self, forKey: .details) {
//                self.details = .pip(pipDetails)
//            } else {
//                self.details = .unknown
//            }

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
//        case .pip(let pipDetails):
//            try container.encode(pipDetails, forKey: .details)
        case .unknown:
            break
        }
    }
}


enum CampaignDetailsTwo {
    case banner(Details)
    case widget(CampaignDetailsForWidget)
    case csat(DetailsCSAT)
//    case pip(DetailsPip)
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

    // Custom initializer for decoding
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

    // Custom method for encoding
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
