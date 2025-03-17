import Foundation

struct CampaignDetailsForWidget: Codable {
    let id: String
    let type: String
    let width: Int?
    let height: Int?
    let widgetImages: [WidgetImage]?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case width
        case height
        case widgetImages = "widget_images"
    }
}
