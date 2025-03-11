
import SwiftUI
import SDWebImageSwiftUI

public protocol WidgetViewDelegate: AnyObject {
    func widgetViewDidUpdateHeight(_ height: CGFloat)
}

public struct WidgetView: View {
    @ObservedObject private var apiService: AppStorys
    @State private var widgetHeight: CGFloat = 150
    @State private var images: [WidgetImage] = []
    @State private var selectedIndex = 0
    @State private var campaignID: String?
    @State private var viewedImageIDs: Set<String> = []
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    var onHeightUpdate: ((CGFloat) -> Void)?
    var position: String
    weak var delegate: WidgetViewDelegate?
    
    private enum Constants {
        static let dotDefaultSize: CGFloat = 10
        static let dotCornerRadius: CGFloat = 5
        static let selectedDotWidth: CGFloat = 25
    }
    
  
        
        public init(apiService: AppStorys, position: String, delegate: WidgetViewDelegate?) {
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
            ForEach(0..<images.count / 2, id: \..self) { index in
                HStack(spacing: 14) {
                    widgetImageView(at: index * 2)
                    widgetImageView(at: index * 2 + 1)
                }
                .padding(14)
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(height: widgetHeight + 10)
    }
    
    private func fullWidgetView() -> some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(images.enumerated()), id: \..offset) { index, image in
                WebImage(url: URL(string: image.imageURL))
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .tag(index)
                    .onTapGesture {
                        didTapWidgetImage(at: index)
                    }
                    .onAppear {
                        didViewWidgetImage(at: index)
                    }
            }
            .padding(14)
        }
        .onChange(of: selectedIndex) { newIndex in
            didViewWidgetImage(at: newIndex)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: widgetHeight + 10)
    }
    
    private func dotIndicators() -> some View {
        HStack(spacing: 4) {
            let numberOfDots = isHalfWidget() ? (images.count + 1) / 2 : images.count
            ForEach(0..<numberOfDots, id: \..self) { index in
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
        WebImage(url: URL(string: images[index].imageURL))
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                didTapWidgetImage(at: index)
            }
            .onAppear {
                if index / 2 == selectedIndex {
                    didViewWidgetImage(at: index)
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
        if let widgetCampaign = apiService.widgetCampaigns.first(where: { $0.position == position }),
           case let .widget(details) = widgetCampaign.details {
            self.images = details.widgetImages.sorted { $0.order < $1.order }
            self.widgetHeight = CGFloat(details.height ?? 150)
            delegate?.widgetViewDidUpdateHeight(self.widgetHeight+30)
            if self.images.count == 1 {
                didViewWidgetImage(at: 0)
            }
            
        }
    }
    
    private func didViewWidgetImage(at index: Int) {
        guard index < images.count else { return }
        let imageID = images[index].id
        guard !viewedImageIDs.contains(imageID) else { return }
        viewedImageIDs.insert(imageID)
        
        if let widgetCampaign = apiService.widgetCampaigns.first(where: { $0.position == position }),
           case let .widget(details) = widgetCampaign.details {
            Task {
                try await apiService.trackAction(type: .view, campaignID: widgetCampaign.id, widgetID: imageID)
            }
        }
    }
    
    private func didTapWidgetImage(at index: Int) {
        guard index < images.count else { return }
        let imageID = images[index].id
        if let widgetCampaign = apiService.widgetCampaigns.first(where: { $0.position == position }) {
            Task {
                try await apiService.trackAction(type: .click, campaignID: widgetCampaign.id, widgetID: imageID)
            }
        }
        if let url = URL(string: images[index].link) {
            UIApplication.shared.open(url)
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
