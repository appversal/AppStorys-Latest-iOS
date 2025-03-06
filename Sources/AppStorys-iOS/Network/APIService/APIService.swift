//import Foundation
//
//public class APIService: ObservableObject, @unchecked Sendable {
//    private let baseURL = "https://backend.appstorys.com/api/v1/users/"
//
//        private var accessToken: String? {
//            get { UserDefaults.standard.string(forKey: "accessToken") }
//            set { UserDefaults.standard.setValue(newValue, forKey: "accessToken") }
//        }
//
//    private enum Endpoints: String {
//        case validateAccount = "validate-account/"
//        case trackScreen = "track-screen/"
//        case trackUser = "track-user/"
//        case trackAction = "track-action/"
//    }
//    public static let shared = APIService()
//    
//    public func validateAccount(appID: String, accountID: String) async throws -> Bool {
//        
//            let url = URL(string: "\(baseURL)\(Endpoints.validateAccount.rawValue)")!
//            var request = URLRequest(url: url)
//            request.httpMethod = "POST"
//            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//            let requestBody: [String: String] = ["app_id": appID, "account_id": accountID]
//            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
//
//            let (data, _) = try await URLSession.shared.data(for: request)
//            let decodedResponse = try JSONDecoder().decode(AccessTokenResponse.self, from: data)
//            accessToken = decodedResponse.accessToken // Persist access token
//
//            return accessToken != nil
//        }
//
//        public func getCampaignList(forScreen screenName: String, position: String) async throws -> [String] {
//            try await waitForValidToken() // Ensure token exists before making request
//
//            let requestBody = TrackScreenRequest(screen_name: screenName, position_list: [position])
//            let response: CampaignListResponse = try await performRequest(
//                endpoint: Endpoints.trackScreen.rawValue,
//                body: requestBody
//            )
//            return response.campaignList
//        }
//
//        // Wait until accessToken is available (prevents race condition)
//        private func waitForValidToken() async throws {
//            var attempts = 0
//            while accessToken == nil {
//                if attempts >= 10 { throw APIError.noAccessToken }
//                try await Task.sleep(nanoseconds: 100_000_000) // Wait 100ms
//                attempts += 1
//            }
//        }
//
//
//    func getCampaigns(campaignList: [String]) async throws -> [CampaignForWidget] {
//        let userId = UUID().uuidString
//        let requestBody = TrackUserRequest(user_id: userId, campaign_list: campaignList)
//        let response: CampaignDataResponse = try await performRequest(
//            endpoint: Endpoints.trackUser.rawValue,
//            body: requestBody
//        )
//        return response.campaigns
//    }
//
//    func trackAction(type: ActionType, userID: String, campaignID: String, widgetID: String) async throws {
//        let requestBody = TrackActionRequest(campaign_id: campaignID, user_id: userID, event_type: type.rawValue, widget_id: widgetID)
//
//        let response: TrackActionResponse = try await performRequest(
//            endpoint: Endpoints.trackAction.rawValue,
//            body: requestBody
//        )
//    }
//
//    private func performRequest<T: Decodable>(
//            endpoint: String,
//            method: String = "POST",
//            body: Encodable? = nil
//        ) async throws -> T {
//            try await waitForValidToken() // Ensure token exists before request
//
//            guard let url = URL(string: "\(baseURL)\(endpoint)") else {
//                throw APIError.invalidURL
//            }
//
//            var request = URLRequest(url: url)
//            request.httpMethod = method
//            request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
//            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//            if let body = body {
//                request.httpBody = try JSONEncoder().encode(body)
//            }
//
//            let (data, response) = try await URLSession.shared.data(for: request)
//            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
//                throw APIError.invalidResponse
//            }
//
//            return try JSONDecoder().decode(T.self, from: data)
//        }
//    

    private struct TrackUserRequest: Codable {
        let user_id: String
        let campaign_list: [String]
    }

    private struct TrackActionRequest: Codable {
        let campaign_id: String
        let user_id: String
        let event_type: String
        let widget_id: String
    }

    private struct TrackScreenRequest: Codable {
        let screen_name: String
        let position_list: [String]
    }
//}
//
