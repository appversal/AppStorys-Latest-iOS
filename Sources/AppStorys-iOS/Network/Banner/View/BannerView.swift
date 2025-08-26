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


struct OverlayBannerView: View {
    @ObservedObject private var apiService: AppStorys
    private let heightUpdateCallback: (CGFloat) -> Void
    @State private var isBannerVisible: Bool = true
    @State private var imageHeight: CGFloat? = nil
    @State private var currentOrientation = UIDevice.current.orientation
    
    init(apiService: AppStorys, heightUpdateCallback: @escaping (CGFloat) -> Void) {
        self.apiService = apiService
        self.heightUpdateCallback = heightUpdateCallback
    }
    
    var body: some View {
        if isBannerVisible, let banCampaign = apiService.banCampaigns.first,
           case let .banner(details) = banCampaign.details {
            
            let styling = details.styling
            let topLeft = CGFloat(styling?.topLeftRadius.flatMap(Double.init) ?? 0)
            let topRight = CGFloat(styling?.topRightRadius.flatMap(Double.init) ?? 0)
            let bottomLeft = CGFloat(styling?.bottomLeftRadius.flatMap(Double.init) ?? 0)
            let bottomRight = CGFloat(styling?.bottomRightRadius.flatMap(Double.init) ?? 0)
            let showCloseButton = styling?.enableCloseButton ?? true
            
            GeometryReader { geometry in
                ZStack {
                    // Banner content
                    VStack(spacing: 0) {
                        if let lottieData = details.lottie_data, !lottieData.isEmpty {
                            LottieView(animationURL: lottieData)
                                .frame(height: imageHeight ?? 200)
                                .mask(
                                    RoundedCorners(
                                        topLeft: topLeft,
                                        topRight: topRight,
                                        bottomLeft: bottomLeft,
                                        bottomRight: bottomRight
                                    )
                                )
                                .onAppear {
                                    calculateAndSetHeight(
                                        containerWidth: geometry.size.width,
                                        details: details,
                                        banCampaign: banCampaign
                                    )
                                }
                                .onTapGesture {
                                    handleBannerTap(banCampaign: banCampaign, details: details)
                                }
                        } else if let imageUrl = details.image {
                            WebImage(url: URL(string: imageUrl))
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: imageHeight)
                                .mask(
                                    RoundedCorners(
                                        topLeft: topLeft,
                                        topRight: topRight,
                                        bottomLeft: bottomLeft,
                                        bottomRight: bottomRight
                                    )
                                )
                                .onAppear {
                                    loadImageAndCalculateHeight(
                                        imageUrl: imageUrl,
                                        containerWidth: geometry.size.width,
                                        details: details,
                                        banCampaign: banCampaign
                                    )
                                }
                                .onTapGesture {
                                    handleBannerTap(banCampaign: banCampaign, details: details)
                                }
                        } else {
                            ProgressView()
                                .frame(height: 200)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    
                    // Close button positioned absolutely in top-right corner
                    if showCloseButton {
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isBannerVisible = false
                                    }
                                    // Hide the overlay window when banner is dismissed
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        apiService.hideBannerOverlay()
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.gray)
                                        .background(Color.white.opacity(0.9))
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                }
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                            }
                            Spacer()
                        }
                    }
                }
                .onChange(of: geometry.size) { newSize in
                    // Handle orientation/size changes
                    recalculateHeight(containerWidth: newSize.width, details: details)
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                // Handle orientation changes
                currentOrientation = UIDevice.current.orientation
            }
        } else {
            // Empty view when banner is hidden
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func calculateAndSetHeight(containerWidth: CGFloat, details: BannerDetails, banCampaign: CampaignModel) {
        let calculatedHeight: CGFloat
        
        if let width = details.width, let height = details.height {
            let aspectRatio = height / width
            calculatedHeight = containerWidth * CGFloat(aspectRatio)
        } else if let height = details.height {
            calculatedHeight = CGFloat(height)
        } else {
            // Use default 16:9 aspect ratio when no dimensions provided
            calculatedHeight = containerWidth * (9.0 / 16.0)
        }
        
        imageHeight = calculatedHeight
        heightUpdateCallback(calculatedHeight)
        
        Task {
            await apiService.trackEvents(eventType: "viewed", campaignId: banCampaign.id)
        }
    }
    
    private func loadImageAndCalculateHeight(imageUrl: String, containerWidth: CGFloat, details: BannerDetails, banCampaign: CampaignModel) {
        DispatchQueue.main.async {
            SDWebImageManager.shared.loadImage(
                with: URL(string: imageUrl),
                options: .highPriority,
                progress: nil
            ) { image, _, _, _, _, _ in
                guard let image = image else {
                    // Fallback when image fails to load
                    DispatchQueue.main.async {
                        let fallbackHeight = containerWidth * (9.0 / 16.0)
                        self.imageHeight = fallbackHeight
                        self.heightUpdateCallback(fallbackHeight)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    let calculatedHeight: CGFloat
                    
                    if let width = details.width, let height = details.height {
                        // Use backend provided dimensions
                        let aspectRatio = height / width
                        calculatedHeight = containerWidth * CGFloat(aspectRatio)
                    } else if let height = details.height {
                        // Use backend provided height only
                        calculatedHeight = CGFloat(height)
                    } else {
                        // Use image's natural aspect ratio when no backend dimensions
                        let imageAspectRatio = image.size.height / image.size.width
                        calculatedHeight = containerWidth * imageAspectRatio
                    }
                    
                    imageHeight = calculatedHeight
                    heightUpdateCallback(calculatedHeight)
                }
            }
        }
        
        Task {
            await apiService.trackEvents(eventType: "viewed", campaignId: banCampaign.id)
        }
    }
    
    private func recalculateHeight(containerWidth: CGFloat, details: BannerDetails) {
        let calculatedHeight: CGFloat
        
        if let width = details.width, let height = details.height {
            let aspectRatio = height / width
            calculatedHeight = containerWidth * CGFloat(aspectRatio)
        } else if let height = details.height {
            calculatedHeight = CGFloat(height)
        } else {
            calculatedHeight = imageHeight ?? 200
        }
        
        if imageHeight != calculatedHeight {
            imageHeight = calculatedHeight
            heightUpdateCallback(calculatedHeight)
        }
    }
    
    private func handleBannerTap(banCampaign: CampaignModel, details: BannerDetails) {
        Task {
            await apiService.trackEvents(eventType: "clicked", campaignId: banCampaign.id)
        }
        apiService.clickEvent(link: details.link, campaignId: banCampaign.id, widgetImageId: "")
    }
}
