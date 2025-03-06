import Foundation

/// A wrapper for decoding the `details` field, which may be either a dictionary or an array.
/// This struct handles both cases to ensure proper decoding.
struct CampaignDetailsWrapper: Codable {
    let details: CampaignDetailsForWidget?

    /// Custom initializer for decoding the `details` field.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Case 1: Try decoding `details` as a dictionary
        if let detailsDict = try? container.decode(CampaignDetailsForWidget.self) {
            self.details = detailsDict
        }
        // Case 2: Try decoding `details` as an array, take the first item if available
        else if let detailsArray = try? container.decode([CampaignDetailsForWidget].self), let firstDetail = detailsArray.first {
            self.details = firstDetail
        }
        // Case 3: If neither works, set `details` to nil
        else {
            self.details = nil
        }
    }
}
