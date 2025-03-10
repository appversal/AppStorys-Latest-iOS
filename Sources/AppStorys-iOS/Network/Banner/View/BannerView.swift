import SwiftUI
import SDWebImageSwiftUI

struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

public struct BannerView: View {
    @ObservedObject private var apiService: AppStorys
    
    public init(apiService: AppStorys) {
        self.apiService = apiService
    }
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            if let banCampaign = apiService.banCampaigns.first {
                if case let .banner(details) = banCampaign.details,
                   let imageUrl = details.image {

                    let imageHeight = details.height ?? 0
                    let validLink = (details.link?.isEmpty == false) ? details.link : nil

                    WebImage(url: URL(string: imageUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: CGFloat(imageHeight)) 
                        .clipShape(RoundedCorners(radius: 5, corners: [.topLeft, .topRight]))
                        .onAppear {
                            Task {
                                await apiService.trackAction(type: .view, campaignID: banCampaign.id, widgetID: "")
                            }
                        }
                        .onTapGesture {
                            Task {
                                await apiService.trackAction(type: .click, campaignID: banCampaign.id, widgetID: "")
                            }
                            if let link = validLink, let url = URL(string: link), UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            }
                        }
                } else {
                    ProgressView()
                }
            }
        }
        .padding(.horizontal, 0)
    }
}


