import SwiftUI
import SDWebImageSwiftUI
import Lottie

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
    @State private var imageHeight: CGFloat? = nil
    @State private var aspectRatio: CGFloat? = nil
    @State private var isImageLoaded: Bool = false
    
    public init(apiService: AppStorys, delegate: BannerViewDelegate?) {
        self.apiService = apiService
        self.delegate = delegate
    }
    
    public var body: some View {
        if isBannerVisible {
            if let banCampaign = apiService.banCampaigns.first {
                if case let .banner(details) = banCampaign.details {
                    
                    let styling = details.styling
                    let topLeft = CGFloat(styling?.topLeftRadius.flatMap(Double.init) ?? 0)
                    let topRight = CGFloat(styling?.topRightRadius.flatMap(Double.init) ?? 0)
                    let bottomLeft = CGFloat(styling?.bottomLeftRadius.flatMap(Double.init) ?? 0)
                    let bottomRight = CGFloat(styling?.bottomRightRadius.flatMap(Double.init) ?? 0)
                    let showCloseButton = styling?.enableCloseButton ?? true
                    
                    ZStack(alignment: .topTrailing) {
                        if let lottieData = details.lottie_data, !lottieData.isEmpty {
                            LottieView(animationURL: lottieData)
                                .frame(height: imageHeight ?? 200)
                                .clipShape(
                                    RoundedCorners(
                                        topLeft: topLeft,
                                        topRight: topRight,
                                        bottomLeft: bottomLeft,
                                        bottomRight: bottomRight
                                    )
                                )
                                .onAppear {
                                    let actualWidth = UIScreen.main.bounds.width
                                    let heightRatio = CGFloat(details.height ?? 200.0) / CGFloat(details.width ?? 375.0)
                                    imageHeight = actualWidth * heightRatio
                                    delegate?.bannerViewDidUpdateHeight(imageHeight!)
                                    
                                    Task {
                                        await apiService.trackAction(type: .view, campaignID: banCampaign.id, widgetID: "")
                                    }
                                }
                                .onTapGesture {
                                    Task {
                                        await apiService.trackAction(type: .click, campaignID: banCampaign.id, widgetID: "")
                                    }
                                    apiService.clickEvent(link: details.link, campaignId: banCampaign.id, widgetImageId: "")
                                }
                        } else if let imageUrl = details.image {
                            WebImage(url: URL(string: imageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: imageHeight)
                                .clipShape(
                                    RoundedCorners(
                                        topLeft: topLeft,
                                        topRight: topRight,
                                        bottomLeft: bottomLeft,
                                        bottomRight: bottomRight
                                    )
                                )
                                .onAppear {
                                    SDWebImageManager.shared.loadImage(
                                        with: URL(string: imageUrl),
                                        options: .highPriority,
                                        progress: nil
                                    ) { image, _, _, _, _, _ in
                                        if let image = image {
                                            DispatchQueue.main.async {
                                                if let width = details.width, let height = details.height {
                                                    let aspectRatio = height / width
                                                    let actualWidth = UIScreen.main.bounds.width
                                                    let calculatedHeight = actualWidth * CGFloat(aspectRatio)
                                                    
                                                    imageHeight = calculatedHeight
                                                } else {
                                                    imageHeight = CGFloat(details.height!)
                                                }
                                                delegate?.bannerViewDidUpdateHeight(imageHeight!)
                                            }
                                        }
                                    }
                                    Task {
                                        await apiService.trackAction(type: .view, campaignID: banCampaign.id, widgetID: "")
                                    }
                                }
                                .onTapGesture {
                                    Task {
                                        await apiService.trackAction(type: .click, campaignID: banCampaign.id, widgetID: "")
                                    }
                                    apiService.clickEvent(link: details.link, campaignId: banCampaign.id, widgetImageId: "")
                                }
                        } else {
                            ProgressView()
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
                                    .padding(20)
                                
                            }
                        }
                    }
                    .padding(.bottom, CGFloat(styling?.marginBottom.flatMap(Double.init) ?? 0))
                    .padding(.horizontal, 0)
                }
            }
        }
    }
}
