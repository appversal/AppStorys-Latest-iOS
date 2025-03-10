
import Foundation
struct DetailsCSAT: Identifiable, Codable {
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
    let displayDelay: Int  
    let csatTitleColor: String
    let csatCtaTextColor: String
    let csatBackgroundColor: String
    let csatOptionTextColour: String
    let csatOptionStrokeColor: String
    let csatCtaBackgroundColor: String
    let csatDescriptionTextColor: String
    let csatSelectedOptionTextColor: String
    let csatSelectedOptionBackgroundColor: String
}

struct FeedbackOptions: Codable {
    let option1: String
    let option2: String
    let option3: String
}
