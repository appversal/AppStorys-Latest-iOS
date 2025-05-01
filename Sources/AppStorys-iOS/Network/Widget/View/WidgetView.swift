import SwiftUI
import SDWebImageSwiftUI
import Lottie

public protocol WidgetViewDelegate: AnyObject {
    func widgetViewDidUpdateHeight(_ height: CGFloat)
}

struct ViewVisibilityModifier: ViewModifier {
    let onAppear: () -> Void
    let onDisappear: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
    }
}

extension View {
    func trackVisibility(onAppear: @escaping () -> Void, onDisappear: @escaping () -> Void) -> some View {
        modifier(ViewVisibilityModifier(onAppear: onAppear, onDisappear: onDisappear))
    }
}

public struct WidgetView: View {
    @ObservedObject private var apiService: AppStorys
    @State private var widgetHeight: CGFloat = 0
    @State private var images: [WidgetImage] = []
    @State private var selectedIndex = 0
    @State private var campaignID: String?
    @State private var viewedImageIDs: Set<String> = []
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State private var visiblePercentage: [Int: CGFloat] = [:]
    var onHeightUpdate: ((CGFloat) -> Void)?
    var position: String?
    weak var delegate: WidgetViewDelegate?
    @State private var imageHeight: CGFloat? = nil
    
    private enum Constants {
        static let dotDefaultSize: CGFloat = 10
        static let dotCornerRadius: CGFloat = 5
        static let selectedDotWidth: CGFloat = 25
        static let visibilityThreshold: CGFloat = 0.5 // 50% visibility threshold
    }
    
    public init(apiService: AppStorys, position: String?, delegate: WidgetViewDelegate?) {
        self.apiService = apiService
        self.position = position
        self.delegate = delegate
    }
    
    public var body: some View {
        VStack(spacing: 5) {
            if images.isEmpty {
                ProgressView()
                    .frame(height: widgetHeight)
            } else {
                if isHalfWidget() {
                    halfWidgetView()
                } else {
                    fullWidgetView()
                }
                if images.count > 1 {
                    dotIndicators()
                }
            }
        }
        .onAppear {
            loadWidgetCampaign()
        }
        .onReceive(apiService.$widgetCampaigns) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                updateWidgetCampaign()
            }
        }
        .onReceive(timer) { _ in
            autoSlideWidget()
        }
    }
    
    private func halfWidgetView() -> some View {
        TabView(selection: $selectedIndex) {
            ForEach(0..<images.count / 2, id: \.self) { index in
                HStack(spacing: 14) {
                    widgetImageView(at: index * 2)
                    widgetImageView(at: index * 2 + 1)
                }
                .padding(14)
                .tag(index)
                .background(GeometryReader { geometry in
                    Color.clear.onAppear {
                        checkVisibility(for: [index * 2, index * 2 + 1], geometry: geometry)
                    }
                })
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(height: widgetHeight + 10)
    }
    
    private func fullWidgetView() -> some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                Group {
                    if let lottieName = image.lottieData {
                        LottieView(animationURL: lottieName)
                            .frame(height: widgetHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        WebImage(url: URL(string: image.imageURL))
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: widgetHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .tag(index)
                .onTapGesture {
                    didTapWidgetImage(at: index)
                }
                .background(GeometryReader { geometry in
                    Color.clear.onAppear {
                        checkVisibility(for: [index], geometry: geometry)
                    }
                })
            }
        }
        .onChange(of: selectedIndex) { newIndex in
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: widgetHeight + 10)
    }
    
    private func checkVisibility(for indices: [Int], geometry: GeometryProxy) {
        DispatchQueue.main.async {
            let frame = geometry.frame(in: .global)
            let screenBounds = UIScreen.main.bounds
            let visibleHeight = min(frame.maxY, screenBounds.maxY) - max(frame.minY, screenBounds.minY)
            let visibility = max(0, visibleHeight / frame.height)
            for index in indices {
                guard index < images.count else { continue }
                visiblePercentage[index] = visibility
                if visibility >= Constants.visibilityThreshold {
                    didViewWidgetImage(at: index)
                }
            }
        }
    }
    
    private func dotIndicators() -> some View {
        HStack(spacing: 4) {
            let numberOfDots = isHalfWidget() ? (images.count + 1) / 2 : images.count
            ForEach(0..<numberOfDots, id: \.self) { index in
                RoundedRectangle(cornerRadius: Constants.dotCornerRadius)
                    .frame(width: index == selectedIndex ? 8 : 5, height: 5)
                    .foregroundColor(index == selectedIndex ? .black : .gray.opacity(0.5))
                    .animation(.easeInOut(duration: 0.3), value: selectedIndex)
            }
        }
        .padding(.top, 6)
        .transition(.opacity)
    }
    
    private func widgetImageView(at index: Int) -> some View {
        Group {
            if let lottieName = images[index].lottieData {
                LottieView(animationURL: lottieName)
                    .frame(maxWidth: .infinity)
                    .frame(height: widgetHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                WebImage(url: URL(string: images[index].imageURL))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: widgetHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onTapGesture {
            didTapWidgetImage(at: index)
        }
        .background(GeometryReader { geometry in
            Color.clear
                .onAppear {
                    checkVisibility(for: [index], geometry: geometry)
                }
        })
    }

    private func setupVisibilityObserver(for index: Int) -> some View {
        let screenBounds = UIScreen.main.bounds

        return GeometryReader { geometry in
            Color.clear
                .preference(key: ViewVisibilityPreferenceKey.self, value: geometry.frame(in: .global))
                .onPreferenceChange(ViewVisibilityPreferenceKey.self) { bounds in
                    let visibleHeight = min(bounds.maxY, screenBounds.maxY) - max(bounds.minY, screenBounds.minY)
                    let visibility = max(0, visibleHeight / bounds.height)

                    DispatchQueue.main.async {
                        visiblePercentage[index] = visibility
                        if visibility >= Constants.visibilityThreshold {
                            didViewWidgetImage(at: index)
                        }
                    }
                }
        }
    }

    private func loadWidgetCampaign() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            updateWidgetCampaign()
        }
        startAutoSlide()
    }
    
    private func updateWidgetCampaign() {
        let widgetCampaign: CampaignModel? = {
                if let position = position {
                    return apiService.widgetCampaigns.first(where: { $0.position == position })
                } else {
                    return apiService.widgetCampaigns.first
                }
            }()

            guard let widgetCampaign = widgetCampaign else { return }
            if case let .widget(details) = widgetCampaign.details {
                self.images = details.widgetImages?.sorted { $0.order < $1.order } ?? []
                if let firstImageURL = images.first?.imageURL, let url = URL(string: firstImageURL) {
                    SDWebImageManager.shared.loadImage(
                        with: url,
                        options: .highPriority,
                        progress: nil
                    ) { image, _, _, _, _, _ in
                        if let _ = image {
                            DispatchQueue.main.async {
                                if let width = details.width, let height = details.height {
                                    widgetHeight = details.height ?? 100
                                } else if let height = details.height {
                                    widgetHeight = CGFloat(height)
                                }
                                delegate?.widgetViewDidUpdateHeight(self.widgetHeight + 30)
                            }
                        }
                    }
                }
            }
        }
    
    
    private func didViewWidgetImage(at index: Int) {
        guard index < images.count else { return }
        let imageID = images[index].id
        guard !viewedImageIDs.contains(imageID) else { return }
        guard visiblePercentage[index] ?? 0 >= Constants.visibilityThreshold else { return }
        viewedImageIDs.insert(imageID)
        
        let widgetCampaign: CampaignModel? = {
            if let position = position {
                return apiService.widgetCampaigns.first(where: { $0.position == position })
            } else {
                return apiService.widgetCampaigns.first
            }
        }()
        
        if let widgetCampaign = widgetCampaign,
           case .widget(_) = widgetCampaign.details {
            Task {
                try? await apiService.trackAction(type: .view, campaignID: widgetCampaign.id, widgetID: imageID)
            }
        }
    }

    
    private func didTapWidgetImage(at index: Int) {
        guard index < images.count else { return }
        let imageID = images[index].id
        guard let widgetCampaign = apiService.widgetCampaigns.first(where: { $0.position == position }) else {
            return
        }
        Task {
            do {
                try await apiService.trackAction(type: .click, campaignID: widgetCampaign.id, widgetID: imageID)
            } catch {
            }
        }
        if let urlString = images[index].link {
            apiService.clickEvent(link: urlString, campaignId: widgetCampaign.id, widgetImageId: imageID)
        }
        
    }
    
    private func startAutoSlide() {
        timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    }
    
    private func autoSlideWidget() {
        guard !images.isEmpty else { return }
        let isHalf = isHalfWidget()
        let totalImages = images.count
        let maxIndex = isHalf ? (totalImages / 2) : totalImages
        guard maxIndex > 0 else { return }
        withAnimation {
            selectedIndex = (selectedIndex + 1) % maxIndex
        }
    }
    
    private func isHalfWidget() -> Bool {
        return apiService.widgetCampaigns.first(where: { $0.position == position })?.details.widgetType == "half"
    }
}

struct ViewVisibilityPreferenceKey: @preconcurrency PreferenceKey {
    @MainActor static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
