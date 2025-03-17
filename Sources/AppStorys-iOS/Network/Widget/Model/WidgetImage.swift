import Foundation

struct WidgetImage: Codable {
    let id: String
    let imageURL: String
    let link: LinkType?
    let order: Int

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL = "image"
        case link
        case order
    }
}
