import Foundation

struct CampaignDetailsWrapper: Codable {
    let details: CampaignDetailsForWidget?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let detailsDict = try? container.decode(CampaignDetailsForWidget.self) {
            self.details = detailsDict
        }
        
        else if let detailsArray = try? container.decode([CampaignDetailsForWidget].self), let firstDetail = detailsArray.first {
            self.details = firstDetail
        }
       
        else {
            self.details = nil
        }
    }
}
