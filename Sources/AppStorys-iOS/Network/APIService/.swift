//
//  File.swift
//  AppStorys-iOS-main-3
//
//  Created by Darshika Gupta on 28/02/25.
//

import SwiftUI

struct ValidateAccountResponse: Codable {
    let access_token: String
    let refresh_token: String
}

struct TrackScreenResponse: Codable {
    let campaigns: [String]
}

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

        // Attempt to decode details as a single object
        if let singleDetails = try? container.decode(Details.self, forKey: .details) {
            details = singleDetails
        }
        // If decoding as a single object fails, try decoding as an array and take the first item
        else if let arrayDetails = try? container.decode([Details].self, forKey: .details), let firstDetail = arrayDetails.first {
            details = firstDetail
        }
        // If both fail, set details to nil
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






class APIService: ObservableObject {
    @Published var accessToken: String?
    @Published var campaigns: [String] = []
    @Published var banCampaigns: [Campaign] = [] // Store BAN campaigns
    @Published var pipCampaigns: [PipCampaign] = [] // Store PIP campaigns
    
    // Define constants for app_id and user_id
    let appID = "afadf960-3975-4ba2-933b-fac71ccc2002"
     let userID = "13555479-077f-445e-87f0-e6eae2e215c5"
    
    private enum Endpoints: String {
        case trackAction = "/track-action/"
    }
    
    func validateAccount() {
        let url = URL(string: "https://backend.appstorys.com/api/v1/users/validate-account/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "app_id": appID,
            "account_id": userID
        ]
        
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(ValidateAccountResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self.accessToken = decodedResponse.access_token
                    print("Access Token: \(decodedResponse.access_token)")
                    
                    // Call trackScreen API
                    self.trackScreen(accessToken: decodedResponse.access_token)
                }
                
            } catch {
                print("Decoding error: \(error)")
            }
        }.resume()
    }
    
    func trackScreen(accessToken: String) {
        let url = URL(string: "https://backend.appstorys.com/api/v1/users/track-screen/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = [
            "screen_name": "Home Screen"
        ]
        
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(TrackScreenResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self.campaigns = decodedResponse.campaigns
                    print("Campaigns: \(decodedResponse.campaigns)")
                    
                    // Call trackUser API after trackScreen
                    self.trackUser(accessToken: accessToken)
                }
                
            } catch {
                print("Decoding error: \(error)")
            }
        }.resume()
    }
    
    func trackUser(accessToken: String) {
        let url = URL(string: "https://backend.appstorys.com/api/v1/users/track-user/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "user_id": userID,
            "campaign_list": [
                "fc7a9fae-aff7-4d02-9a4e-8bacebf403ee",
                "0f30ef0d-5f6e-44f7-b2a2-4a7fb7480d8e",
                "77960810-2f33-48c0-9323-9efb58100447",
                "fb87b39c-c75f-4379-97f5-2fea794b146c",
                "cd419e53-9d05-4ad4-b2b0-5765f5c27be2",
                "ff21bd7b-30d0-4129-80ef-67e1e0ae1170",
                "8cc34561-dfaf-46c1-8f97-9674e050c5e7"
            ],
            "attributes": [
                ["age": "1"]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Print the raw JSON response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON Response: \(jsonString)")
            } else {
                print("Failed to convert response to String.")
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(TrackUserResponse.self, from: data)
                let decodedResponsePip = try JSONDecoder().decode(TrackUserResponsePip.self, from: data)
                
                DispatchQueue.main.async {
                    self.banCampaigns = decodedResponse.campaigns.filter { $0.campaignType == "BAN" }
                    
                    self.pipCampaigns = decodedResponsePip.campaigns.filter { $0.campaignType == "PIP" }
                    
                    print("BAN Campaigns: \(self.banCampaigns)")
                    print("PIP Campaigns: \(self.pipCampaigns)")
                }
                
            } catch {
                print("Decoding error: \(error)")
            }
        }.resume()
    }
    
    func trackAction(type: ActionType, userID: String, campaignID: String ) async throws {
        let requestBody = TrackActionRequest(campaign_id: campaignID, user_id: userID, event_type: type.rawValue)

        // Perform the request and get the response
        let response: TrackActionResponse = try await performRequest(
            endpoint: Endpoints.trackAction.rawValue,
            body: requestBody
        )

        // Print the response for debugging purposes
        print("Response: \(response)")
    }

    
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String = "POST",
        body: Encodable? = nil
    ) async throws -> T {
        guard let accessToken else {
            throw APIError.noAccessToken
        }

        guard let url = URL(string: "https://backend.appstorys.com/api/v1/users/track-action/") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check if the response is a valid HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Check if the status code is in the success range (200-299)
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = "Error with status code: \(httpResponse.statusCode)"
            print(errorMessage) // Log the status code for debugging
            throw APIError.invalidResponse
        }

        return try JSONDecoder().decode(T.self, from: data)
    }


    private struct TrackUserRequest: Codable {
        let user_id: String
        let campaign_list: [String]
    }

    private struct TrackActionRequest: Codable {
        let campaign_id: String
        let user_id: String
        let event_type: String
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


//struct SwiftUIView: View {
//    @StateObject private var apiService = APIService()
//    
//    var body: some View {
//        VStack {
//            Text("Access Token:")
//                .font(.headline)
//            Text(apiService.accessToken ?? "No Token")
//                .foregroundColor(.blue)
//                .padding()
//            
//            Text("Campaigns:")
//                .font(.headline)
//            ForEach(apiService.campaigns, id: \.self) { campaign in
//                Text(campaign)
//                    .foregroundColor(.green)
//                    .padding()
//            }
//            
//            Button("Validate Account & Track User") {
//                apiService.validateAccount()
//            }
//            .padding()
//            .background(Color.blue)
//            .foregroundColor(.white)
//            .cornerRadius(10)
//        }
//        .padding()
//    }
//}
//
//#Preview {
//    SwiftUIView()
//}
