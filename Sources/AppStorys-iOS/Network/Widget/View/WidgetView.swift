import SwiftUI
import SDWebImageSwiftUI

public struct WidgetView: View {
    @ObservedObject private var apiService: AppStorys
    @State private var widgetHeight: CGFloat = 150
    @State private var images: [WidgetImage] = []
    @State private var selectedIndex = 0
    @State private var campaignID: String?
    @State private var viewedImageIDs: Set<String> = []
    
    var position: String

    private enum Constants {
        static let dotDefaultSize: CGFloat = 10
        static let dotCornerRadius: CGFloat = 5
        static let selectedDotWidth: CGFloat = 25
    }

    public init(apiService: AppStorys, position: String) {
        self.apiService = apiService
        self.position = position
    }

    public var body: some View {
        VStack(spacing: 16) {
            if images.isEmpty {
                EmptyView().frame(height: widgetHeight)
            } else {
                if isHalfWidget() {

                    TabView(selection: $selectedIndex) {
                        ForEach(0..<images.count / 2, id: \.self) { index in
                            HStack(spacing: 0) {
                                // Show two images at a time
                                WebImage(url: URL(string: images[index * 2].imageURL))
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .padding(.horizontal,10)
                                    
                                    .onTapGesture {
                                        didTapWidgetImage(at: index * 2)
                                    }
                                    .onAppear {
                                        // Only track if the image is visible
                                        if index == selectedIndex {
                                            didViewWidgetImage(at: index * 2)
                                        }
                                    }

                                WebImage(url: URL(string: images[index * 2 + 1].imageURL))
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .onTapGesture {
                                        didTapWidgetImage(at: index * 2 + 1)
                                    }
                                    .padding(.horizontal,10)
                                   
                                    .onAppear {
                                        // Only track if the image is visible
                                        if index == selectedIndex {
                                            didViewWidgetImage(at: index * 2 + 1)
                                        }
                                    }
                            }.padding(.top, 5)
                            .padding(.leading,5)
                            .padding(.trailing,5)
                            .padding(.bottom, 10)// Remove padding around the images
                            .tag(index)

                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: widgetHeight)
                } else {
                    // For Full widgets, show one image at a time
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            WebImage(url: URL(string: image.imageURL))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal)
                                .padding(.vertical)
                                .tag(index)
                                .onTapGesture {
                                    didTapWidgetImage(at: index)
                                }
                                .onAppear {
                                    // Only track if the image is visible
                                    if index == selectedIndex {
                                        didViewWidgetImage(at: index)
                                    }
                                }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: widgetHeight)
                }

                if images.count > 1 {
                    HStack(spacing: 6) {
                        // For half widgets, only run the loop till half the number of images
                        let numberOfDots = isHalfWidget() ? (images.count + 1) / 2 : images.count
                        
                        ForEach(0..<numberOfDots, id: \.self) { index in
                            RoundedRectangle(cornerRadius: Constants.dotCornerRadius)
                                .frame(width: index == selectedIndex ? Constants.selectedDotWidth : Constants.dotDefaultSize,
                                       height: Constants.dotDefaultSize)
                                .foregroundColor(index == selectedIndex ? .black : .gray.opacity(0.5))
                                .animation(.easeInOut(duration: 0.3), value: selectedIndex)
                        }
                    }
                }

            }
        }
        .frame(height: widgetHeight + 50)
        .onAppear {
            Task {
                await loadWidgetCampaign()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !apiService.widgetCampaigns.isEmpty {
                    updateWidgetCampaign()
                } else {
                }
                startAutoSlide()
            }
        }
        .onReceive(apiService.$widgetCampaigns) { _ in
            updateWidgetCampaign()
        }
    }


    private func loadWidgetCampaign() async {
        // Your async loading logic here
    }

    private func updateWidgetCampaign() {
        // Filter widget campaigns by position
        guard let widgetCampaign = apiService.widgetCampaigns.first(where: { $0.position == position }) else {
            return
        }

        campaignID = widgetCampaign.id
        guard case let .widget(details) = widgetCampaign.details else {
            return
        }

        DispatchQueue.main.async {
            widgetHeight = CGFloat(details.height ?? 150)
            images = details.widgetImages.sorted { $0.order < $1.order }
        }
    }

    private func startAutoSlide() {
        // Timer to automatically change the selected index every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            // Ensure UI updates happen on the main thread
            DispatchQueue.main.async {
                withAnimation {
                    // Increment index and wrap around if it exceeds the image count
                    selectedIndex = (selectedIndex + 1) % (isHalfWidget() ? (images.count / 2) : images.count)
                }
            }
        }
    }

    private func isHalfWidget() -> Bool {
        // Determine if widget type is "half"
        
        
        return apiService.widgetCampaigns.first(where: { $0.position == position })?.details.widgetType == "half"
    }

    private func didViewWidgetImage(at index: Int) {
        guard let campaignID, let viewedImage = images[safe: index] else { return }

        // Check if this image has already been viewed
        if viewedImageIDs.contains(viewedImage.id) {
            return
        }

        // Track the view action
        Task {
            try await apiService.trackAction(type: .view, campaignID: campaignID, widgetID: viewedImage.id)

            // After tracking, add the image to the viewed set
            viewedImageIDs.insert(viewedImage.id)
        }
    }

    private func didTapWidgetImage(at index: Int) {
        guard let campaignID, let tappedImage = images[safe: index] else { return }

        // Track the click action
        Task {
            try await apiService.trackAction(type: .click, campaignID: campaignID, widgetID: tappedImage.id)
        }
        if let url = URL(string: tappedImage.imageURL) {
                UIApplication.shared.open(url)
            }
    }
}

#Preview {
    WidgetView(apiService: AppStorys(), position: "widget_one")
}
