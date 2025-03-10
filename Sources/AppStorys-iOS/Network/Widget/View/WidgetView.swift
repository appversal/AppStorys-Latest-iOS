
import SwiftUI
import SDWebImageSwiftUI

public struct WidgetView: View {
    @ObservedObject private var apiService: AppStorys
    @State private var widgetHeight: CGFloat = 150
    @State private var images: [WidgetImage] = []
    @State private var selectedIndex = 0
    @State private var campaignID: String?
    @State private var viewedImageIDs: Set<String> = []
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
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
        VStack(spacing: 20) {
            if images.isEmpty {
                ProgressView()
                    .frame(height: widgetHeight)
            } else {
                if isHalfWidget() {

                    TabView(selection: $selectedIndex) {
                        ForEach(0..<images.count / 2, id: \.self) { index in
                            HStack(spacing: 14) {
                             
                                WebImage(url: URL(string: images[index * 2].imageURL))
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                                    .scaledToFill()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture {
                                        didTapWidgetImage(at: index * 2 + 1)
                                    }
                                    .onAppear {
                                        
                                        if index == selectedIndex {

                                            didViewWidgetImage(at: index * 2 + 1)
                                        }
                                    }
                            }.padding(14)
                            .tag(index)

                        }
                    }
                   
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: widgetHeight+10)
                } else {
                  
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            WebImage(url: URL(string: image.imageURL))
                                .resizable()
                                scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .tag(index)
                                .onTapGesture {
                                    didTapWidgetImage(at: index)
                                }
                                .onAppear {
                                    if index == selectedIndex {
                                        didViewWidgetImage(at: index)
                                    }
                                }
                                
                        }.padding(14)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height:widgetHeight+10 ?? 100)
                }


                if images.count > 1 {
                    HStack(spacing: 4) { // Reduced spacing for a compact look
                        let numberOfDots = isHalfWidget() ? (images.count + 1) / 2 : images.count

                        ForEach(0..<numberOfDots, id: \.self) { index in
                            RoundedRectangle(cornerRadius: Constants.dotCornerRadius)
                                .frame(
                                    width: index == selectedIndex ? 8 : 5, // Decreased width
                                    height: 5 // Decreased height
                                )
                                .foregroundColor(index == selectedIndex ? .black : .gray.opacity(0.5))
                                .animation(.easeInOut(duration: 0.3), value: selectedIndex)
                        }
                    }
                    .padding(.top, 6) // Slightly reduced padding
                    .transition(.opacity)
                }



            }
        }
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
        .onReceive(timer) { _ in
            guard !images.isEmpty else { return }

            let isHalf = isHalfWidget()
            let totalImages = images.count
            let maxIndex = isHalf ? (totalImages / 2) : totalImages

            guard maxIndex > 0 else { return }

            withAnimation {
                selectedIndex = (selectedIndex + 1) % maxIndex
            }
        }

    }


    private func loadWidgetCampaign() async {
    }

    private func updateWidgetCampaign() {
        guard let widgetCampaign = apiService.widgetCampaigns.first(where: { $0.position == position }) else {
            return
        }

        campaignID = widgetCampaign.id

        guard case let .widget(details) = widgetCampaign.details else {
            return
        }

        DispatchQueue.main.async {
            self.widgetHeight = CGFloat(details.height ?? 150)
            self.images = details.widgetImages.sorted { $0.order < $1.order }
        }
    }


    private func startAutoSlide() {
        timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    }


    private func isHalfWidget() -> Bool {
        return apiService.widgetCampaigns.first(where: { $0.position == position })?.details.widgetType == "half"
    }

    private func didViewWidgetImage(at index: Int) {
        guard let campaignID else { return }
        
        if isHalfWidget() {
            let firstImageIndex = index * 2
            let secondImageIndex = firstImageIndex + 1
            
            trackView(for: firstImageIndex)
            trackView(for: secondImageIndex)
        } else {
            trackView(for: index)
        }
    }

    private func trackView(for index: Int) {
        guard index < images.count else { return }
        
        let viewedImage = images[index]

        if viewedImageIDs.contains(viewedImage.id) {
            return
        }

        Task {
            try await apiService.trackAction(type: .view, campaignID: campaignID!, widgetID: viewedImage.id)
            DispatchQueue.main.async {
                self.viewedImageIDs.insert(viewedImage.id)
            }
        }
    }


    private func didTapWidgetImage(at index: Int) {
        guard let campaignID, let tappedImage = images[safe: index] else { return }
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

