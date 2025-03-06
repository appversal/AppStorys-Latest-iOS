//
//  AppStorys.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 06/03/25.
//

//import Foundation
//import SwiftUI
//
//public class AppStorys: ObservableObject {
//    static let shared = AppStorys()
//    @Published var campaigns: [Campaign] = []
//    @Published var accessToken: String?
//    
//    private let baseURL = "https://backend.appstorys.com/api/v1"
//    private var appId: String? {
//        UserDefaults.standard.string(forKey: "app_id")
//    }
//    
//    private func makeRequest(endpoint: String, method: String = "POST", body: [String: Any]?) async throws -> Data? {
//        guard let url = URL(string: "\(baseURL)/\(endpoint)") else { return nil }
//        var request = URLRequest(url: url)
//        request.httpMethod = method
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        if let token = accessToken {
//            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//        }
//        if let body = body {
//            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
//        }
//        
//        let (data, response) = try await URLSession.shared.data(for: request)
//        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
//            print("Error in API call to \(endpoint): \(response)")
//            return nil
//        }
//        return data
//    }
//    
//    func trackScreen(appId: String, screenName: String) async {
//        guard let data = try? await makeRequest(endpoint: "users/track-screen/", body: ["app_id": appId, "screen_name": screenName]) else { return }
//        
//        if let jsonResponse = try? JSONDecoder().decode(TrackScreenResponse.self, from: data) {
//            DispatchQueue.main.async {
//                self.campaigns = jsonResponse.campaigns
//            }
//        }
//    }
//    
//    func trackUser(userId: String, attributes: [[String: String]]) async {
//        guard let appId = appId else { return }
//        _ = try? await makeRequest(endpoint: "users/update-user/", body: ["user_id": userId, "app_id": appId, "attributes": attributes])
//    }
//    
//    func trackUserAction(userId: String, campaignId: String, eventType: String, storySlide: String? = nil, widgetImage: String? = nil) async {
//        var body: [String: Any] = ["campaign_id": campaignId, "user_id": userId, "event_type": eventType]
//        if let storySlide = storySlide { body["story_slide"] = storySlide }
//        if let widgetImage = widgetImage { body["widget_image"] = widgetImage }
//        
//        _ = try? await makeRequest(endpoint: "users/track-action/", body: body)
//    }
//    
//    func verifyAccount(accountId: String, appId: String) async {
//        UserDefaults.standard.setValue(appId, forKey: "app_id")
//        
//        guard let data = try? await makeRequest(endpoint: "admins/validate-account/", body: ["account_id": accountId, "app_id": appId]) else { return }
//        
//        if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
//            if let token = jsonResponse["access_token"] as? String {
//                DispatchQueue.main.async {
//                    self.accessToken = token
//                    UserDefaults.standard.setValue(token, forKey: "access_token")
//                }
//            }
//        }
//    }
//    
//    func captureCsatResponse(csatId: String, userId: String, rating: Int, feedbackOption: String? = nil, additionalComments: String? = nil) async {
//        var body: [String: Any] = ["csat": csatId, "user_id": userId, "rating": rating]
//        if let feedbackOption = feedbackOption { body["feedback_option"] = feedbackOption }
//        if let additionalComments = additionalComments { body["additional_comments"] = additionalComments }
//        
//        _ = try? await makeRequest(endpoint: "campaigns/capture-csat-response/", body: body)
//    }
//    
//    func captureSurveyResponse(surveyId: String, userId: String, responseOptions: [String], comment: String? = nil) async {
//        var body: [String: Any] = ["user_id": userId, "survey": surveyId, "responseOptions": responseOptions]
//        if let comment = comment { body["comment"] = comment }
//        
//        _ = try? await makeRequest(endpoint: "campaigns/capture-survey-response/", body: body)
//    }
//    
//    static let preview: AppStorys = {
//        let instance = AppStorys()
//        instance.accessToken = "MockAccessToken"
//        instance.campaigns = [Campaign(id: "123", position: "top")]
//        return instance
//    }()
//}
//
//struct TrackScreenResponse: Codable {
//    let campaigns: [Campaign]
//}
//
//struct Campaign: Codable {
//    let id: String
//    let position: String
//}
////
////struct ContentView: View {
////    @StateObject private var appStorys = AppStorys.shared
////    @State private var accessToken: String?
////    
////    private let userId = "YOUR_USER_ID"
////    private let appId = "1163a1a2-61a8-486c-b263-7252f9a502c2"
////    private let accountId = "5bb1378d-9f32-4da8-aed1-1ee44d086db7"
////    private let screenName = "Home Screen"
////    private let attributes: [[String: String]] = [["key": "value"]]
////    
////    var body: some View {
////        VStack {
////            Text("AppStorys SDK")
////                .font(.title)
////            if let token = accessToken {
////                Text("Access Token: \(token)")
////                    .font(.subheadline)
////            }
////        }
////        .onAppear {
//////            #if !DEBUG
////            Task {
////                await appStorys.verifyAccount(accountId: accountId, appId: appId)
////                await appStorys.trackScreen(appId: appId, screenName: screenName)
////                await appStorys.trackUser(userId: userId, attributes: attributes)
////                DispatchQueue.main.async {
////                    self.accessToken = UserDefaults.standard.string(forKey: "access_token")
////                }
////            }
//////            #endif
////        }
////    }
////}
////
////struct ContentView_Previews: PreviewProvider {
////    static var previews: some View {
////        ContentView()
////            .environmentObject(AppStorys.preview)
////    }
////}
