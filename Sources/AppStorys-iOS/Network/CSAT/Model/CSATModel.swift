
import Foundation

//struct TrackUserResponseCSAT: Codable {
//    let user_id: String
//    let campaigns: [CSATCampaign]
//}

//struct CSATCampaign: Codable {
//    let id: String
//    let campaignType: String
//    let details: [DetailsCSAT]?
//    let position: String?
//
//    enum CodingKeys: String, CodingKey {
//        case id
//        case campaignType = "campaign_type"
//        case details
//        case position
//    }
//
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        id = try container.decode(String.self, forKey: .id)
//        campaignType = try container.decode(String.self, forKey: .campaignType)
//        position = try container.decodeIfPresent(String.self, forKey: .position)
//
//        // ✅ Handle `details` as Dictionary OR Array
//        if let detailsDict = try? container.decode(DetailsCSAT.self, forKey: .details) {
//            details = [detailsDict] // Convert single dictionary to array
//        } else if let detailsArray = try? container.decode([DetailsCSAT].self, forKey: .details) {
//            details = detailsArray // Use array as-is
//        } else {
//            details = nil // Default to nil if neither format works
//        }
//    }
//}

struct DetailsCSAT: Identifiable, Codable {
    let id: String
    let title: String
    let height: Double?
    let width: Double?
    let styling: CSATStyling?  // ✅ Optional since it can be missing/null
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
    let displayDelay: Int  // ✅ Corrected to match JSON
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
