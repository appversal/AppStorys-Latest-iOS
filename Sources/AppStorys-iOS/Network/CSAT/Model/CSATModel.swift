
import Foundation

struct CsatDetails: Identifiable, Codable {
    let id: String
    let title: String
    let height: Double?
    let width: Double?
    let styling: CSATStyling?
    let thankyouImage: String?
    let thankyouText: String?
    let thankyouDescription: String?
    let descriptionText: String?
    let feedbackOption: FeedbackOptions
    let campaign: String
    let link: String
    
    private enum CodingKeys: String, CodingKey {
        case id, title, height, width, styling
        case thankyouImage = "thankyouImage"
        case thankyouText = "thankyouText"
        case thankyouDescription = "thankyouDescription"
        case descriptionText = "description_text"
        case feedbackOption = "feedback_option"
        case campaign, link
    }
}

struct CSATStyling: Codable {
    let displayDelay: Int?
    let csatTitleColor: String
    let csatCtaTextColor: String
    let csatBackgroundColor: String?
    let csatOptionTextColour: String
    let csatOptionStrokeColor: String
    let csatCtaBackgroundColor: String?
    let csatDescriptionTextColor: String
    let csatSelectedOptionTextColor: String
    let csatSelectedOptionBackgroundColor: String
    let csatLowStarColor: String?
    let csatHighStarColor: String?
    let csatAdditionalTextColor: String?
    let csatUnselectedStarColor: String?

    enum CodingKeys: String, CodingKey {
        case displayDelay = "delayDisplay"
        case csatTitleColor
        case csatCtaTextColor
        case csatBackgroundColor
        case csatOptionTextColour
        case csatOptionStrokeColor
        case csatCtaBackgroundColor
        case csatDescriptionTextColor
        case csatSelectedOptionTextColor
        case csatSelectedOptionBackgroundColor
        case csatLowStarColor
        case csatHighStarColor
        case csatAdditionalTextColor
        case csatUnselectedStarColor
    }
}

struct FeedbackOptions: Codable {
    let option1: String
    let option2: String
    let option3: String?
}

