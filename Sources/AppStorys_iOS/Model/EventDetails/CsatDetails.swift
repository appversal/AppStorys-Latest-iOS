//
//  CsatDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/10/25.
//


import Foundation

public struct CsatDetails: Codable, Sendable {
    public let id: String
    public let title: String?
    public let height: Int?
    public let width: Int?
    public let styling: CsatStyling?
    public let thankyouImage: String?
    public let thankyouText: String?
    public let thankyouDescription: String?
    public let descriptionText: String?
    public let feedbackOption: FeedbackOptions?
    public let link: String?
    public let highStarText: String?
    public let lowStarText: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, height, width, styling, link
        case thankyouImage = "thankyouImage"
        case thankyouText = "thankyouText"
        case thankyouDescription = "thankyouDescription"
        case descriptionText = "description_text"
        case feedbackOption = "feedback_option"
        case highStarText = "highStarText"
        case lowStarText = "lowStarText"
    }
}

public struct CsatStyling: Codable, Sendable {
    public let displayDelay: Int?
    public let csatTitleColor: String?
    public let csatCtaTextColor: String?
    public let csatBackgroundColor: String?
    public let csatOptionTextColour: String?
    public let csatOptionStrokeColor: String?
    public let csatCtaBackgroundColor: String?
    public let csatDescriptionTextColor: String?
    public let csatSelectedOptionTextColor: String?
    public let csatSelectedOptionBackgroundColor: String?
    public let csatLowStarColor: String?
    public let csatHighStarColor: String?
    public let csatAdditionalTextColor: String?
    public let csatUnselectedStarColor: String?
    public let fontSize: Int?
}

public struct FeedbackOptions: Codable, Sendable {
    public let option1: String?
    public let option2: String?
    public let option3: String?
}