import Foundation

struct CampaignDetailsWrapper: Codable {
    let details: WidgetDetails?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let detailsDict = try? container.decode(WidgetDetails.self) {
            self.details = detailsDict
        }
        
        else if let detailsArray = try? container.decode([WidgetDetails].self), let firstDetail = detailsArray.first {
            self.details = firstDetail
        }
       
        else {
            self.details = nil
        }
    }
}
