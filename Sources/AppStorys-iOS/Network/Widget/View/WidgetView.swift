
import SwiftUI
import SDWebImageSwiftUI

public protocol WidgetViewDelegate: AnyObject {
    func widgetViewDidUpdateHeight(_ height: CGFloat)
}

public struct WidgetView: View {
    @ObservedObject private var apiService: AppStorys
    @State private var widgetHeight: CGFloat = 0
    @State private var images: [WidgetImage] = []
    @State private var selectedIndex = 0
    @State private var campaignID: String?
    @State private var viewedImageIDs: Set<String> = []
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    var onHeightUpdate: ((CGFloat) -> Void)?
    var position: String
    weak var delegate: WidgetViewDelegate?
    @State private var imageHeight: CGFloat? = nil
    
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
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: widgetHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .tag(index)
                    .onTapGesture {
                        didTapWidgetImage(at: index)
                    }
                    .onAppear {
                        didViewWidgetImage(at: index)
                    }
            }
            
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
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: widgetHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
//        print("Updating Widget Campaign for position: \(position)")
//        
        if let widgetCampaign = apiService.widgetCampaigns.first(where: { $0.position == position }) {
//            print("Found widget campaign for position: \(position)")
            
            if case let .widget(details) = widgetCampaign.details {
                self.images = details.widgetImages!.sorted { $0.order < $1.order }
//                print("Total images found: \(self.images.count)")
                
                if let backendHeight = details.height {
                    // Use the height from the backend if available
                    self.widgetHeight = CGFloat(backendHeight)
//                    print("Using backend height: \(self.widgetHeight)")
                    delegate?.widgetViewDidUpdateHeight(self.widgetHeight + 30)
                } else if let firstImageURL = images.first?.imageURL, let url = URL(string: firstImageURL) {
                    // Fetch image size to determine height dynamically
//                    print("Fetching image from URL: \(url)")
                    
                    SDWebImageManager.shared.loadImage(
                        with: url,
                        options: .highPriority,
                        progress: nil
                    ) { image, _, _, _, _, _ in
                        if let image = image {
                            DispatchQueue.main.async {
                                let intrinsicWidth = image.size.width
                                let intrinsicHeight = image.size.height
                                let screenWidth = UIScreen.main.bounds.width
                                
                                let aspectRatio = intrinsicHeight / intrinsicWidth
                                let calculatedHeight = screenWidth * aspectRatio
                                
                                self.widgetHeight = calculatedHeight
//                                print("Image loaded successfully")
//                                print("Image dimensions - Width: \(intrinsicWidth), Height: \(intrinsicHeight)")
//                                print("Calculated widget height: \(self.widgetHeight)")
                                
                                delegate?.widgetViewDidUpdateHeight(self.widgetHeight + 30)
                            }
                        } else {
//                            print("Failed to load image from URL: \(url)")
                        }
                    }
                }
                
                if self.images.count == 1 {
//                    print("Only one image available, calling didViewWidgetImage(at: 0)")
                    didViewWidgetImage(at: 0)
                }
            } else {
//                print("No valid widget details found for position: \(position)")
            }
        } else {
//            print("No widget campaign found for position: \(position)")
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
        guard let widgetCampaign = apiService.widgetCampaigns.first(where: { $0.position == position }) else {
            return
        }
        Task {
            do {
                try await apiService.trackAction(type: .click, campaignID: widgetCampaign.id, widgetID: imageID)
            } catch {
//                print("Error tracking action: \(error.localizedDescription)")
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
