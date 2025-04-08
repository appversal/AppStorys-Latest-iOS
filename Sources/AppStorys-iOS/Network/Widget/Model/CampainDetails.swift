import Foundation

struct WidgetDetails: Codable {
    let id: String
    let type: String
    let width: Double?
    let height: Double?
    let widgetImages: [WidgetImage]?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case width
        case height
        case widgetImages = "widget_images"
    }
}
