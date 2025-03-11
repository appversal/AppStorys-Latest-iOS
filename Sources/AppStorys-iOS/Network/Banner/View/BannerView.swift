import SwiftUI
import SDWebImageSwiftUI


public protocol BannerViewDelegate: AnyObject {
    func bannerViewDidUpdateHeight(_ height: CGFloat)
}


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
    weak var delegate: BannerViewDelegate? // Delegate reference
    
    public init(apiService: AppStorys, delegate: BannerViewDelegate?) {
        self.apiService = apiService
        self.delegate = delegate
    }
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            if let banCampaign = apiService.banCampaigns.first {
                if case let .banner(details) = banCampaign.details,
                   let imageUrl = details.image {
                    
                    let imageHeight = CGFloat(details.height ?? 200)
                    let validLink = (details.link?.isEmpty == false) ? details.link : nil

                    WebImage(url: URL(string: imageUrl))
                        .resizable()
                        .frame(maxWidth: .infinity, maxHeight: imageHeight)
                        .clipShape(RoundedCorners(radius: 5, corners: [.topLeft, .topRight]))
                        .onAppear {
                            DispatchQueue.main.async {
                                delegate?.bannerViewDidUpdateHeight(imageHeight)
                            }
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
