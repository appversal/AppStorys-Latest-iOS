import Foundation

struct WidgetImage: Codable {
    let id: String
    let imageURL: String
    let link: LinkType?
    let order: Int
    let lottieData: String?

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL = "image"
        case link
        case order
        case lottieData = "lottie_data"
    }
}
