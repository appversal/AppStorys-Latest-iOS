//
//  SurveyView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.

import SwiftUI

public struct Survey: View {
    @State private var currentQuestionIndex = 0
    @State private var showSurvey = true
    @State private var showInputBox = false
    @State private var selectedOptions: [String] = []
    @State private var othersText = ""
    @ObservedObject private var apiService: AppStorys
    
    public init(apiService: AppStorys) {
        self.apiService = apiService
    }
    private func closeSurvey() {
        showSurvey = false
    }
    
    private func hexToColor(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    public var body: some View {
        GeometryReader { geometry in
            if showSurvey {
                ZStack (){
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    if let surveyCampaign = apiService.surveyCampaigns.first {
                        if case let .survey(details) = surveyCampaign.details,
                           let name = details.name {
                            let id = details.id
                            let styling = details.styling
                            let surveyQuestion = details.surveyQuestion
                            let surveyOptions = details.surveyOptions
                            let hasOthers = details.hasOthers
                            let campaign = details.campaign
                            VStack {
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    ZStack {
                                        Text(details.name!)
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(hexToColor(details.styling["surveyQuestionColor"] ?? "#000000"))
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.top, geometry.size.height * 0.01)
                                        
                                        HStack {
                                            Spacer()
                                            Button(action: closeSurvey) {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(hexToColor(details.styling["ctaTextIconColor"] ?? "#FFFFFF"))
                                                    .padding(10)
                                                    .background(hexToColor(details.styling["ctaBackgroundColor"] ?? "#000000"))
                                                    .clipShape(Circle())
                                            }
                                            .padding(.top, 10)
                                        }
                                    }
                                    .frame(height: geometry.size.height * 0.05)
                                    
                                    Text(surveyQuestion)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(hexToColor(details.styling["surveyQuestionColor"] ?? "#000000"))
                                        .padding(.top, 8)
                                    
                                    VStack(spacing: 12) {
                                        ForEach(getSurveyOptions(), id: \.id) { option in
                                            if option.id != "" && option.name != "" {
                                                Button(action: {
                                                    toggleOption(option: option.name)
                                                }) {
                                                    HStack {
                                                        Text(option.id)
                                                            .font(.system(size: 12, weight: .semibold))
                                                            .foregroundColor(.black)
                                                            .padding(.vertical, 4)
                                                            .padding(.horizontal, 8)
                                                            .background(Color.white)
                                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 18)
                                                                    .stroke(Color.black, lineWidth: 0.8)
                                                            )
                                                        
                                                        Text(option.name)
                                                            .font(.system(size: 14, weight: .regular))
                                                            .foregroundColor(selectedOptions.contains(option.name)
                                                                             ? hexToColor(details.styling["selectedOptionTextColor"] ?? "#FFFFFF")
                                                                             : hexToColor(details.styling["optionTextColor"] ?? "#000000"))
                                                            .padding(.leading, 12)
                                                        
                                                        Spacer()
                                                    }
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 12)
                                                    .background(
                                                        selectedOptions.contains(option.name)
                                                        ? hexToColor(details.styling["selectedOptionColor"] ?? "#000000")
                                                        : hexToColor(details.styling["optionColor"] ?? "#FFFFFF")
                                                    )
                                                    .cornerRadius(12)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        if showInputBox {
                                            TextField("Please enter Others text…..upto 200 chars", text: $othersText)
                                                .font(.system(size: 13))
                                                .padding(.leading, geometry.size.height * 0.015)
                                                .frame(height: geometry.size.height * 0.057)
                                                .background(Color.white)
                                                .foregroundColor(.black)
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(hexToColor(details.styling["othersBackgroundColor"] ?? "#000000"), lineWidth: 1)
                                                )
                                                .padding(.bottom, geometry.size.width * 0.04)
                                        }
                                        
                                        Button(action: {
                                            if !selectedOptions.isEmpty {
                                                captureSurveyResponse(
                                                    surveyId: details.id,
                                                    userId: KeychainHelper.shared.get(key: "userIDAppStorys")!,
                                                    selectedOptions: selectedOptions,
                                                    comment: othersText.isEmpty ? nil : othersText
                                                )
                                                closeSurvey()
                                            }
                                        }) {
                                            Text("SUBMIT")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(hexToColor(details.styling["ctaTextIconColor"] ?? "#FFFFFF"))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 14)
                                                .background(hexToColor(details.styling["ctaBackgroundColor"] ?? "#000000"))
                                                .cornerRadius(12)
                                        }
                                        .padding(.top, 8)
                                    }
                                    
                                    Spacer().frame(height: geometry.size.width * 0.03)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(hexToColor(details.styling["backgroundColor"] ?? "#FFFFFF"))
                                .cornerRadius(18)
                                .frame(width: geometry.size.width * 0.9)
                                .frame(maxHeight: geometry.size.height * 0.9)
                                
                                Spacer()
                            }
                            .frame(width: geometry.size.width)
                                .onAppear {
                                    Task {
                                        await apiService.trackAction(type: .view, campaignID: surveyCampaign.id, widgetID: "")
                                    }
                                }
                        }
                    }
                }
            } else {
                EmptyView()
            }
        }
        
    }
    func toggleOption(option: String) {
        if selectedOptions.contains(option) {
            selectedOptions.removeAll { $0 == option }
        } else {
            selectedOptions.append(option)
        }
        
        showInputBox = selectedOptions.contains("Others")
    }
    
    func getSurveyOptions() -> [SurveyOption] {
        var options: [SurveyOption] = []
        
        if let surveyCampaign = apiService.surveyCampaigns.first {
            if case let .survey(details) = surveyCampaign.details {
                let surveyOptions = details.surveyOptions
                
                let sortedOptions = surveyOptions.sorted { lhs, rhs in
                    let lhsNumber = Int(lhs.key.replacingOccurrences(of: "option", with: "")) ?? 0
                    let rhsNumber = Int(rhs.key.replacingOccurrences(of: "option", with: "")) ?? 0
                    return lhsNumber < rhsNumber
                }
                
                for (index, value) in sortedOptions.enumerated() {
                    let optionId = String(UnicodeScalar(65 + index)!)
                    options.append(SurveyOption(id: optionId, name: value.value))
                }
                
                if details.hasOthers {
                    let nextOptionId = String(UnicodeScalar(65 + options.count)!)
                    options.append(SurveyOption(id: nextOptionId, name: "Others"))
                }
            }
        }
        return options
    }
    
    private func captureSurveyResponse(surveyId: String, userId: String, selectedOptions: [String], comment: String?) {
        guard let accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys") else {
            return
        }
        
        let url = URL(string: "https://backend.appstorys.com/api/v1/campaigns/capture-survey-response/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "survey": surveyId,
            "user_id": userId,
            "responseOptions": selectedOptions,
            "comment": comment ?? ""
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return
            }
        }.resume()
    }
}
