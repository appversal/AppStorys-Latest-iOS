//
//  WidgetView.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Smooth progress bar transitions when timer completes
//

import SwiftUI
import UIKit
import Kingfisher

// MARK: - Public Widget View

public struct WidgetView: View {
    // MARK: - Properties
    
    public let campaignId: String
    public let details: WidgetDetails
    
    @State private var currentIndex: Int = 0
    @State private var isPresentedLinkError: Bool = false
    @State private var autoScrollTask: Task<Void, Never>?
    @State private var progress: Double = 0.0
    @State private var isTransitioning: Bool = false // ✅ NEW: Track transition state
    
    private let autoScrollInterval: TimeInterval = 5.0
    
    // MARK: - Computed Properties
    
    private var images: [WidgetImage] {
        details.widgetImages ?? []
    }
    
    private var styling: WidgetStyling? {
        details.styling
    }
    
    private var cornerRadiusValue: CGFloat {
        radius(from: styling?.topLeftRadius)
    }
    
    private var heightValue: CGFloat {
        calculateHeight()
    }
    
    // MARK: - Initializer
    
    public init(campaignId: String, details: WidgetDetails) {
        self.campaignId = campaignId
        self.details = details
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 8) {
            contentView
                .frame(height: heightValue)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadiusValue, style: .continuous))
                .overlay(
                    // Progress indicators for full-width carousel
                    Group{
                        if shouldShowProgressIndicators {
                            progressIndicators(count: images.count)
                                .padding(.bottom, 8)
                        }
                    }
                    ,alignment: .bottom
                )
            
//            // Progress indicators for full-width carousel
//            if shouldShowProgressIndicators {
//                progressIndicators(count: images.count)
//                    .padding(.top, 4)
//            }
        }
        .padding(.top, marginValue(from: styling?.topMargin))
        .padding(.bottom, marginValue(from: styling?.bottomMargin))
        .padding(.leading, marginValue(from: styling?.leftMargin))
        .padding(.trailing, marginValue(from: styling?.rightMargin))
        .alert(isPresented: $isPresentedLinkError) {
            Alert(
                title: Text("Unable to open link"),
                message: Text("The link is invalid or cannot be opened."),
                dismissButton: .default(Text("OK"))
            )
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        if images.isEmpty {
            emptyStateView
        } else if details.type == "full" {
            fullWidthCarousel
        } else if details.type == "half" {
            halfWidthLayout
        } else {
            emptyStateView
        }
    }
    
    // MARK: - Full Width Carousel
    
    private var fullWidthCarousel: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(images.enumerated()), id: \.element.id) { idx, widgetImage in
                imageCard(for: widgetImage)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onAppear {
            handleCarouselAppear()
        }
        .onDisappear {
            stopAutoScroll()
        }
        .onChange(of: currentIndex) { oldIndex, newIndex in
            handleIndexChange(from: oldIndex, to: newIndex)
        }
        // ✅ FIX: Detect manual swipes via gesture
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { _ in
                    // User manually swiped - reset timer
                    handleManualSwipe()
                }
        )
    }
    
    // MARK: - Half Width Layout
    
    private var halfWidthLayout: some View {
        HStack(spacing: 12) {
            if let firstImage = images[safe: 0] {
                imageCard(for: firstImage)
                    .frame(maxWidth: .infinity)
            }
            
            if let secondImage = images[safe: 1] {
                imageCard(for: secondImage)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            handleHalfWidthAppear()
        }
    }
    
    // MARK: - Image Card
    
    @ViewBuilder
    private func imageCard(for widgetImage: WidgetImage) -> some View {
        Button(action: {
            handleTap(on: widgetImage)
        }) {
            AppStorysImageView(
                url: URL(string: widgetImage.image),
                contentMode: .fill,
                showShimmer: true,
                cornerRadius: cornerRadiusValue,
                onSuccess: {
                    Logger.debug("✅ Widget image loaded: \(widgetImage.id)")
                },
                onFailure: { error in
                    Logger.warning("⚠️ Widget image failed: \(widgetImage.id)")
                    // Track failed image loads
                    Task {
                        await trackEvent(
                            name: "image_load_failed",
                            metadata: [
                                "widget_image": widgetImage.id,
                                "error": error.localizedDescription
                            ]
                        )
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Progress Indicators
    
    @ViewBuilder
    private func progressIndicators(count: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                progressIndicator(for: index, isActive: index == currentIndex)
            }
        }
        .padding(.vertical,6)
        .padding(.horizontal,12)
        .background(Capsule(style: .continuous).fill(.thinMaterial))
    }
    
    @ViewBuilder
    private func progressIndicator(for index: Int, isActive: Bool) -> some View {
        let indicatorWidth: CGFloat = isActive ? 24 : 8
        
        ZStack(alignment: .leading) {
            // Background track
            Capsule(style: .continuous)
                .fill(.secondary)
                .frame(width: indicatorWidth, height: 8)
            
            // ✅ FIX: Only show progress fill when active AND not transitioning
            if isActive && !isTransitioning {
                Capsule(style: .continuous)
                    .fill(.white)
                    .frame(width: indicatorWidth * CGFloat(progress), height: 8)
                    // Smooth progress animation
                    .animation(.linear(duration: 0.1), value: progress)
                    // Fade in after shape transition completes
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            }
        }
        // ✅ FIX: Single animation for shape changes
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isActive)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No widget content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }
    
    // MARK: - Lifecycle Handlers
    
    private func handleCarouselAppear() {
        // Track first image view
        if let firstImage = images.first {
            Task {
                await trackEvent(name: "viewed", metadata: ["widget_image": firstImage.id])
            }
        }
        
        // Start auto-scroll if multiple images
        if images.count > 1 {
            startAutoScroll()
        }
    }
    
    private func handleHalfWidthAppear() {
        // Track both visible images
        Task {
            if let first = images[safe: 0] {
                await trackEvent(name: "viewed", metadata: ["widget_image": first.id])
            }
            if let second = images[safe: 1] {
                await trackEvent(name: "viewed", metadata: ["widget_image": second.id])
            }
        }
    }
    
    private func handleIndexChange(from oldIndex: Int, to newIndex: Int) {
        guard oldIndex != newIndex, let image = images[safe: newIndex] else { return }
        
        Task {
            await trackEvent(name: "viewed", metadata: ["widget_image": image.id])
        }
    }
    
    // ✅ NEW: Handle manual swipe by user
    private func handleManualSwipe() {
        Logger.debug("👆 Manual swipe detected - resetting timer")
        
        // Cancel current animation
        stopAutoScroll()
        
        // Small delay to let the swipe animation complete
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            startAutoScroll()
        }
    }
    
    // MARK: - Auto-Scroll Logic
    
    private func startAutoScroll() {
        guard images.count > 1 else { return }
        
        autoScrollTask = Task { @MainActor in
            while !Task.isCancelled {
                // ✅ FIX: Clear transition flag and reset progress
                isTransitioning = false
                progress = 0.0
                
                // Wait for shape animation to complete
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s
                
                let startDate = Date()
                let animationInterval = autoScrollInterval - 0.3 // Reserve time for transition
                
                // Animate progress bar smoothly
                while Date().timeIntervalSince(startDate) < animationInterval {
                    guard !Task.isCancelled else { return }
                    
                    let elapsed = Date().timeIntervalSince(startDate)
                    progress = min(1.0, elapsed / animationInterval)
                    
                    try? await Task.sleep(nanoseconds: 16_000_000) // ~60 FPS
                }
                
                // ✅ FIX: Start transition phase
                isTransitioning = true
                progress = 1.0
                
                // Small pause at 100% before transitioning
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                
                // Advance to next slide
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex = (currentIndex + 1) % images.count
                }
                
                // Wait for slide transition to complete
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            }
        }
        
        Logger.debug("▶️ Auto-scroll started for widget: \(campaignId)")
    }
    
    private func stopAutoScroll() {
        autoScrollTask?.cancel()
        autoScrollTask = nil
        progress = 0.0
        isTransitioning = false
        
        Logger.debug("⏸️ Auto-scroll stopped for widget: \(campaignId)")
    }
    
    // MARK: - Actions
    
    private func handleTap(on image: WidgetImage) {
        Task {
            await trackEvent(name: "clicked", metadata: ["widget_image": image.id])
        }
        
        guard let link = image.link,
              !link.trimmingCharacters(in: .whitespaces).isEmpty,
              let url = URL(string: link) else {
            return
        }
        
        openURL(url)
    }
    
    private func openURL(_ url: URL) {
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if !success {
                        isPresentedLinkError = true
                        Logger.warning("⚠️ Failed to open URL: \(url.absoluteString)")
                    }
                }
            } else {
                isPresentedLinkError = true
                Logger.warning("⚠️ Cannot open URL: \(url.absoluteString)")
            }
        }
    }
    
    // MARK: - Tracking Helper
    
    private func trackEvent(name: String, metadata: [String: Any]? = nil) async {
        await AppStorys.shared.trackEvents(
            eventType: name,
            campaignId: campaignId,
            metadata: metadata
        )
    }
    
    // MARK: - Layout Calculations
    
    private func calculateHeight() -> CGFloat {
        guard let width = details.width,
              let height = details.height,
              width > 0, height > 0 else {
            return 200 // Default fallback
        }
        
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding = marginValue(from: styling?.leftMargin) +
                                marginValue(from: styling?.rightMargin)
        let availableWidth = screenWidth - horizontalPadding
        
        let aspectRatio = CGFloat(height) / CGFloat(width)
        let calculatedHeight = availableWidth * aspectRatio
        
        // Clamp to reasonable bounds
        return min(max(calculatedHeight, 150), 400)
    }
    
    // MARK: - Style Helpers
    
    private func radius(from string: String?) -> CGFloat {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty,
              let doubleVal = Double(s) else {
            return 12 // Default radius
        }
        return CGFloat(doubleVal)
    }
    
    private func marginValue(from string: String?) -> CGFloat {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty,
              let doubleVal = Double(s) else {
            return 0
        }
        return CGFloat(doubleVal)
    }
    
    // MARK: - Computed Flags
    
    private var shouldShowProgressIndicators: Bool {
        details.type == "full" && images.count > 1
    }
}

// MARK: - Safe Array Extension

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview Support

//#if DEBUG
//struct WidgetView_Previews: PreviewProvider {
//    static var previews: some View {
//        VStack(spacing: 20) {
//            // Full width carousel
//            WidgetView(
//                campaignId: "test-full",
//                details: WidgetDetails(
//                    id: "1",
//                    type: "full",
//                    width: 400,
//                    height: 200,
//                    widgetImages: [
//                        WidgetImage(
//                            id: "img1",
//                            image: "https://picsum.photos/400/200",
//                            link: "https://example.com"
//                        ),
//                        WidgetImage(
//                            id: "img2",
//                            image: "https://picsum.photos/400/201",
//                            link: "https://example.com"
//                        )
//                    ],
//                    styling: nil
//                )
//            )
//            
//            // Half width layout
//            WidgetView(
//                campaignId: "test-half",
//                details: WidgetDetails(
//                    id: "2",
//                    type: "half",
//                    width: 400,
//                    height: 150,
//                    widgetImages: [
//                        WidgetImage(
//                            id: "img3",
//                            image: "https://picsum.photos/200/150",
//                            link: nil
//                        ),
//                        WidgetImage(
//                            id: "img4",
//                            image: "https://picsum.photos/201/150",
//                            link: nil
//                        )
//                    ],
//                    styling: nil
//                )
//            )
//            
//            Spacer()
//        }
//        .padding()
//    }
//}
//#endif
