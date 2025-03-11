import SwiftUI
import SDWebImageSwiftUI


public protocol BannerViewDelegate: AnyObject {
    func bannerViewDidUpdateHeight(_ height: CGFloat)
}


struct RoundedCorners: Shape {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath()
        
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addArc(withCenter: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                    radius: topRight, startAngle: .pi * 1.5, endAngle: 0, clockwise: true)
        
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addArc(withCenter: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                    radius: bottomRight, startAngle: 0, endAngle: .pi * 0.5, clockwise: true)
        
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addArc(withCenter: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                    radius: bottomLeft, startAngle: .pi * 0.5, endAngle: .pi, clockwise: true)
        
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addArc(withCenter: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                    radius: topLeft, startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
        
        path.close()
        
        return Path(path.cgPath)
    }
}

public struct BannerView: View {
    @ObservedObject private var apiService: AppStorys
    weak var delegate: BannerViewDelegate?
    @State private var isBannerVisible: Bool = true
    
    public init(apiService: AppStorys, delegate: BannerViewDelegate?) {
        self.apiService = apiService
        self.delegate = delegate
    }
    
    public var body: some View {
        if isBannerVisible {
            ZStack(alignment: .topTrailing) {
                if let banCampaign = apiService.banCampaigns.first {
                    if case let .banner(details) = banCampaign.details,
                       let imageUrl = details.image {
                        
                        let imageHeight = CGFloat(details.height ?? 200)
                        let validLink = (details.link?.isEmpty == false) ? details.link : nil
                        let styling = details.styling
                        let topLeft = CGFloat(styling?.topLeftRadius.flatMap(Double.init) ?? 0)
                        let topRight = CGFloat(styling?.topRightRadius.flatMap(Double.init) ?? 0)
                        let bottomLeft = CGFloat(styling?.bottomLeftRadius.flatMap(Double.init) ?? 0)
                        let bottomRight = CGFloat(styling?.bottomRightRadius.flatMap(Double.init) ?? 0)
                        let showCloseButton = styling?.enableCloseButton ?? true
                        WebImage(url: URL(string: imageUrl))
                            .resizable()
                            .frame(maxWidth: .infinity, maxHeight: imageHeight)
                            .clipShape(
                                RoundedCorners(
                                    topLeft: topLeft,
                                    topRight: topRight,
                                    bottomLeft: bottomLeft,
                                    bottomRight: bottomRight
                                )
                            )
                            .padding(.bottom, CGFloat(styling?.marginBottom.flatMap(Double.init) ?? 0))
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
                        if showCloseButton {
                            Button(action: {
                                withAnimation {
                                    isBannerVisible = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.gray)
                                    .background(Color.white.opacity(0.8))
                                    .clipShape(Circle())
                                    .padding(8)
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
}
