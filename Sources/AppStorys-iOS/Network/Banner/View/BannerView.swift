import SwiftUI

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

                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: CGFloat(imageHeight))
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: CGFloat(imageHeight))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .onTapGesture {
                                    if let link = validLink, let url = URL(string: link), UIApplication.shared.canOpenURL(url) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                        case .failure:
                            Text("Failed to load image")
                            EmptyView() //
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: CGFloat(imageHeight))
                    .frame(maxWidth: .infinity)
                } else {
                    EmptyView() 
                }
            }
        }
        .padding(.horizontal, 0)
    }
}

#Preview {
    BannerView(apiService: AppStorys())
}
