import SwiftUI

import SDWebImageSwiftUI

import SwiftUI
import SDWebImageSwiftUI

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

                    let imageHeight = details.height ?? 60
                    let validLink = (details.link?.isEmpty == false) ? details.link : nil

                    WebImage(url: URL(string: imageUrl))
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: CGFloat(imageHeight))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .onTapGesture {
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

#Preview {
    BannerView(apiService: AppStorys())
}
