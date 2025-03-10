//
//  CSATView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 08/03/25.
//

import SwiftUI
// MARK: - CSAT View
public struct CsatView: View {

    @ObservedObject private var apiService: AppStorys
    @State private var showCSAT: Bool = true
    @State private var selectedStars: Int = 0
    @State private var showThanks: Bool = false
    @State private var showFeedback: Bool = false
    @State private var selectedOption: String?
    @State private var csatLoaded: Bool = false
    @State private var additionalComments: String = ""

    public init(apiService: AppStorys) {
        self.apiService = apiService
    }


    public var body: some View {
        if showCSAT, let csatCampaign = apiService.csatCampaigns.first {
            if case let .csat(details) = csatCampaign.details {
                VStack {
                    Spacer() // Pushes the survey up when height increases
                    ZStack(alignment: .topTrailing) {
                        if csatLoaded {
                            VStack(alignment: .leading) {
                                if showThanks {
                                    thanksView()
                                } else {
                                    surveyView()
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(hexToColor(details.styling!.csatBackgroundColor))
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .bottom)) // Smooth animation when appearing
                        }

                        // Close Button (X)
                        if csatLoaded {
                            Button(action: {
                                showCSAT = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                                    .padding(10)
                            }
                            .offset(x: -20, y: 0)
                        }
                    }.padding(.bottom, showFeedback ? 120 : 0) // Adjust bottom padding dynamically
                        .padding(.bottom, showThanks ? -80 : 30)
                        .animation(.easeInOut(duration: 0.3), value: showFeedback) // Smooth transition
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom) // Keep it at the bottom initially

                .onAppear {
                    print("CsatView appeared")
                    csatLoaded = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        csatLoaded = true
                    }
                    trackAction(campaignID: csatCampaign.id, actionType: .view)
                        
                    
                    
                    scheduleCsatDisplay()
                }
            }
        }
    }


    // MARK: - Submit Button Update
    private func submitFeedback() {
        print("Feedback submitted:")
        print("Stars: \(selectedStars)")
        print("Selected Option: \(selectedOption ?? "None")")
        print("Additional Comments: \(additionalComments)")

        if let csatCampaign = apiService.csatCampaigns.first {
            if case let .csat(details) = csatCampaign.details   {
                captureCsatResponse(csatId: details.id, userId: UserDefaults.standard.string(forKey: "userID")!, rating: selectedStars, feedbackOption: selectedOption, additionalComments: additionalComments)
            }
        }
        showThanks = true

    }

    private func captureCsatResponse(csatId: String, userId: String, rating: Int, feedbackOption: String?, additionalComments: String?) {
        guard let userID = UserDefaults.standard.string(forKey: "userID"),
              let accessToken = UserDefaults.standard.string(forKey: "accessToken") else {
            print("Error: No access token or user ID")
            return
        }

        let url = URL(string: "https://backend.appstorys.com/api/v1/campaigns/capture-csat-response/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "csat": csatId,
            "user_id": userID,
            "rating": rating,
            "feedback_option": feedbackOption ?? "",
            "additional_comments": additionalComments ?? ""
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error submitting CSAT response: \(error)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("Error: Invalid server response")
                return
            }
            print("CSAT response submitted successfully")
        }.resume()
    }

    // MARK: - Survey View
    @ViewBuilder
    private func surveyView() -> some View {
        if let csatCampaign = apiService.csatCampaigns.first {
            if case let .csat(details) = csatCampaign.details {
                VStack(alignment: .leading, spacing: 14) {
                    Text(details.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(hexToColor(details.styling!.csatTitleColor))
                    
                    Text(details.descriptionText!)
                        .foregroundColor(hexToColor(details.styling!.csatTitleColor))
                    
                    // Star Rating
                    HStack {
                        ForEach(1..<6, id: \.self) { index in
                            Image(systemName: index <= selectedStars ? "star.fill" : "star")
                                .foregroundColor(index <= selectedStars ? .yellow : .gray)
                                .font(.title)
                                .onTapGesture {
                                    withAnimation {
                                        selectedStars = index  // Update selection
                                        showFeedback = index < 4
                                    }
                                    
                                    print("Selected Stars: \(selectedStars)") // Debugging
                                    
                                    if index >= 4 {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            submitFeedback()
                                        }
                                    }
                                }
                        }
                    }
                    .id(selectedStars) // Forces UI update when selection changes

                    if showFeedback == false {
                        Text("Rate Us!")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.top, 10)
                    }
                    
                    // Feedback Options
                    // Feedback Options
                    if showFeedback {
                        Text("Please tell us what went wrong?")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.top, 10)
                        
                        let feedbackOptions = [details.feedbackOption.option1,
                                               details.feedbackOption.option2,
                                               details.feedbackOption.option3]
                        
                        ForEach(feedbackOptions, id: \.self) { option in
                            Button(action: {
                                selectedOption = option
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 50)
                                        .fill(hexToColor(selectedOption == option ? details.styling!.csatCtaBackgroundColor : details.styling!.csatBackgroundColor))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 50)
                                                .stroke(selectedOption == option ? Color.clear : Color.gray, lineWidth: 1)
                                        )
                                    
                                    Text(option)
                                        .padding(.horizontal, 16) // Keep text padding
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundColor(selectedOption == option ? .white : hexToColor(details.styling!.csatDescriptionTextColor))
                                }
                                .frame(height: 50)
                            }
                        }
                        
                        // Additional Comments
                        TextField("Additional comments", text: $additionalComments)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.gray),
                                alignment: .bottom
                            )
                            .padding(.top, 10)
                        
                        // Submit Button
                        Button(action: {
                            print("Done button tapped") // Debugging
                            submitFeedback()

                            DispatchQueue.main.async {
                                showThanks = true
                            }

                            let campaignID = apiService.csatCampaigns.first?.id ?? ""
                            print(campaignID)
                            let accessToken = UserDefaults.standard.string(forKey: "accessToken")



                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                if !campaignID.isEmpty, accessToken != nil {
                                    trackAction(campaignID: campaignID, actionType: .click)
                                } else {
                                    print("Skipping trackAction: Missing campaign ID or access token")
                                }
                            }

                        }) {
                            Text("Done")
                                .font(.headline)
                                .foregroundColor(hexToColor(details.styling!.csatCtaTextColor))
                                .frame(width: 100, height: 50)
                                .background(hexToColor(details.styling!.csatCtaBackgroundColor))
                                .cornerRadius(25)
                        }
                        
                    }
                    
                }
                
            }
        }
    }
    // MARK: - Thanks View
    @ViewBuilder
    private func thanksView() -> some View {
        if let csatCampaign = apiService.csatCampaigns.first {
            if case let .csat(details) = csatCampaign.details {
                VStack(spacing: 8) {
                    
                    // Handle thankyouImage correctly
                    if let imageUrl = URL(string: details.thankyouImage!), !details.thankyouImage!.isEmpty {
                        AsyncImage(url: imageUrl) { image in
                            image.resizable()
                                .scaledToFit()
                                .frame(height: 66)
                        } placeholder: {
                            ProgressView()
                        }
                    }
                    
                    Text(details.thankyouText!)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Text(details.thankyouDescription!)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        
                        if !details.link.isEmpty {
                            let urlString = details.link
                            print("Found link: \(urlString)")

                            if let url = URL(string: urlString) {
                                if UIApplication.shared.canOpenURL(url) {
                                    print("Opening URL: \(url)")
                                    UIApplication.shared.open(url)
                                } else {
                                    print("Cannot open URL: \(url)")
                                }
                            } else {
                                print("Invalid URL format: \(urlString)")
                            }
                        } else {
                            print("No link found in campaign details")
                        }

                        showCSAT = false
                        UserDefaults.standard.setValue(true, forKey: "csat_loaded")
                    }) {
                        Text("Done")
                            .font(.headline)
                            .foregroundColor(hexToColor(details.styling!.csatCtaTextColor))
                            .frame(width: 100, height: 50)
                            .background(hexToColor(details.styling!.csatCtaBackgroundColor))
                            .cornerRadius(25)
                    }
                }
                
                .frame(maxWidth: .infinity)
            }
        }
    }


    // MARK: - CSAT Delay Logic
    private func scheduleCsatDisplay() {
        if let csatCampaign = apiService.csatCampaigns.first {
            if case let .csat(details) = csatCampaign.details {
                let delay = Int(details.styling!.displayDelay)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
                    if !csatLoaded {
                        showCSAT = true
                    }
                }
            }
        }
        
    }


    // MARK: - Color Conversion
    func hexToColor(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }

    @MainActor
    func trackAction(campaignID: String, actionType: ActionType) {
        guard let accessToken = UserDefaults.standard.string(forKey: "accessToken") else {
            print("Error: No access token or user ID")
            return
        }

        Task {
            do {
                await apiService.trackAction(type: actionType, campaignID: campaignID, widgetID: "")
                print("Action tracked: \(actionType.rawValue) for campaign \(campaignID)")
            }
        }
    }

}
