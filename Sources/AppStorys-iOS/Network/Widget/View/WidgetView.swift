
import SwiftUI
import SDWebImageSwiftUI

public struct WidgetView: View {
    @ObservedObject private var apiService: AppStorys
    @State private var widgetHeight: CGFloat = 150
    @State private var images: [WidgetImage] = []
    @State private var selectedIndex = 0
    @State private var campaignID: String?
    @State private var viewedImageIDs: Set<String> = []

    // Added position property to filter the widget campaign
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
        VStack(spacing: 0) {
            if images.isEmpty {
                ProgressView()
                    .frame(height: widgetHeight)
            } else {
                if isHalfWidget() {

                    TabView(selection: $selectedIndex) {
                        ForEach(0..<images.count / 2, id: \.self) { index in
                            HStack(spacing: 0) {
                             
                                WebImage(url: URL(string: images[index * 2].imageURL))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .padding(.horizontal,10)
                                    .padding(.leading,10)
                                    .onTapGesture {
                                        didTapWidgetImage(at: index * 2)
                                    }
                                    .onAppear {
                                       
                                        if index == selectedIndex {
                                            didViewWidgetImage(at: index * 2)
                                        }
                                    }

                                WebImage(url: URL(string: images[index * 2 + 1].imageURL))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .onTapGesture {
                                        didTapWidgetImage(at: index * 2 + 1)
                                    }
                                    .padding(.horizontal,10)
                                    .padding(.trailing,10)
                                    .onAppear {
                                        
                                        if index == selectedIndex {

                                            didViewWidgetImage(at: index * 2 + 1)
                                        }
                                    }
                            }
                            .padding(.bottom,10)
                            .tag(index)

                        }
                    }
                   
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: widgetHeight+20)
                } else {
                  
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            WebImage(url: URL(string: image.imageURL))
                                .resizable()
                                .padding(.leading,20)
                                .padding(.trailing,20)
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .tag(index)
                                .onTapGesture {
                                    didTapWidgetImage(at: index)
                                }
                                .onAppear {
                                    if index == selectedIndex {
                                        didViewWidgetImage(at: index)
                                    }
                                }
                                
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: widgetHeight+20)
                }


                if images.count > 1 {
                    HStack(spacing: 6) {
                        let numberOfDots = isHalfWidget() ? (images.count + 1) / 2 : images.count
                        
                        ForEach(0..<numberOfDots, id: \.self) { index in
                            RoundedRectangle(cornerRadius: Constants.dotCornerRadius)
                                .frame(width: index == selectedIndex ? Constants.selectedDotWidth : Constants.dotDefaultSize,
                                       height: Constants.dotDefaultSize)
                                .foregroundColor(index == selectedIndex ? .black : .gray.opacity(0.5))
                                .animation(.easeInOut(duration: 0.3), value: selectedIndex)
                        }
                    }.padding(.top,15)
                   
                    .transition(.opacity)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateWidgetCampaign()
            }

        }
    }


    private func loadWidgetCampaign() async {
        // Your async loading logic here
    }

    private func updateWidgetCampaign() {
        guard let widgetCampaign = apiService.widgetCampaigns.first(where: { $0.position == position }) else {
//            print("❌ No widget campaign found for position: \(position)")
            return
        }
        
//        print("✅ Found widget campaign: \(widgetCampaign)")
        campaignID = widgetCampaign.id

        guard case let .widget(details) = widgetCampaign.details else {
//            print("❌ Campaign details not of type .widget")
            return
        }

        DispatchQueue.main.async {
            self.widgetHeight = CGFloat(details.height ?? 150)
            self.images = details.widgetImages.sorted { $0.order < $1.order }
//            print("✅ Widget images loaded: \(self.images.count)")
        }
    }


    private func startAutoSlide() {
//        print("🟢 Starting auto-slide...")

        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
//            print("\n🔄 Auto-slide triggered")

            DispatchQueue.main.async {
//                print("📌 Current selectedIndex: \(self.selectedIndex)")
                
                let isHalf = self.isHalfWidget()
                let totalImages = self.images.count

                // ✅ Ensure we do not divide by zero
                let maxIndex: Int
                if totalImages == 1 {
//                    print("⏸️ Auto-slide skipped (Only one image available)")
                    return  // ⛔️ Exit early if only one image exists
                } else if isHalf {
                    maxIndex = max(1, totalImages / 2)  // ✅ Ensure at least 1
                } else {
                    maxIndex = totalImages
                }

//                print("🖼️ Widget Type: \(isHalf ? "Half" : "Full")")
//                print("🖼️ Total Images: \(totalImages), Max Index: \(maxIndex)")

                guard maxIndex > 0 else {
//                    print("⚠️ Skipping auto-slide due to zero max index.")
                    return
                }

                withAnimation {
                    self.selectedIndex = (self.selectedIndex + 1) % maxIndex
//                    print("➡️ Updated selectedIndex: \(self.selectedIndex)")
                }
            }
        }
    }


    private func isHalfWidget() -> Bool {
        // Determine if widget type is "half"
        
        
        return apiService.widgetCampaigns.first(where: { $0.position == position })?.details.widgetType == "half"
    }

    private func didViewWidgetImage(at index: Int) {
        guard let campaignID else { return }
        
        if isHalfWidget() {
            // For half widgets, each `selectedIndex` represents a pair of images
            let firstImageIndex = index * 2
            let secondImageIndex = firstImageIndex + 1
            
            trackView(for: firstImageIndex)
            trackView(for: secondImageIndex)
        } else {
            // For full widgets, each `selectedIndex` represents a single image
            trackView(for: index)
        }
    }

    private func trackView(for index: Int) {
        guard index < images.count else { return }
        
        let viewedImage = images[index]

        // Prevent duplicate view tracking
        if viewedImageIDs.contains(viewedImage.id) {
            return
        }

        Task {
            try await apiService.trackAction(type: .view, campaignID: campaignID!, widgetID: viewedImage.id)
            
            // Mark the image as viewed
            DispatchQueue.main.async {
                self.viewedImageIDs.insert(viewedImage.id)
            }
        }
    }


    private func didTapWidgetImage(at index: Int) {
        guard let campaignID, let tappedImage = images[safe: index] else { return }

        // Track the click action
        Task {
            try await apiService.trackAction(type: .click, campaignID: campaignID, widgetID: tappedImage.id)
        }
        if let url = URL(string: tappedImage.link) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}

