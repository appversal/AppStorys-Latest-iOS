import Foundation

struct CampaignListResponse: Codable {
    let campaignList: [String]

    enum CodingKeys: String, CodingKey {
        case campaignList = "campaigns"
    }
}
