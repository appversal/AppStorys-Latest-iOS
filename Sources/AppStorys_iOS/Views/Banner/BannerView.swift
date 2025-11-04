//
//  BannerView.swift
//  AppStorys_iOS
//
//  Simplified banner campaign view with bottom positioning
//  ✅ UPDATED: Using AppStorysImageView + proper corner radius handling
//

import SwiftUI

struct BannerView: View {
    let campaignId: String
    let details: BannerDetails
    
    @State private var isVisible = true
    @State private var hasTrackedView = false
    @State private var imageLoaded = false
    
    var body: some View {
        if isVisible {
            VStack {
                Spacer()
                bannerContent
                
                .onTapGesture {
                    handleTap()
                }
            }
            .safeAreaPadding(.bottom, 60 + bottomPadding)
            .padding(.horizontal, horizontalPadding)
            
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
            .onAppear {
                trackViewIfNeeded()
            }
        }
    }
    
    @ViewBuilder
    private var bannerContent: some View {
        ZStack(alignment: .topTrailing) {
            if let imageUrlString = details.image, let imageUrl = URL(string: imageUrlString) {
                AppStorysImageView(
                    url: imageUrl,
                    contentMode: .fill,
                    showShimmer: true,
                    cornerRadius: 0,
                    onSuccess: {
                        imageLoaded = true
                        Logger.info("✅ Banner image loaded: \(campaignId)")
                    },
                    onFailure: { error in
                        Logger.error("❌ Banner image failed to load: \(campaignId)", error: error)
                    }
                )
                .frame(height: bannerHeight)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: topLeftRadius,
                        bottomLeadingRadius: bottomLeftRadius,
                        bottomTrailingRadius: bottomRightRadius,
                        topTrailingRadius: topRightRadius
                    )
                )
                .onTapGesture {
                    handleTap()
                }
            } else {
                placeholderView
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: topLeftRadius,
                            bottomLeadingRadius: bottomLeftRadius,
                            bottomTrailingRadius: bottomRightRadius,
                            topTrailingRadius: topRightRadius
                        )
                    )
            }
            
            if details.styling?.enableCloseButton == true {
                closeButton
                    .padding(8)
            }
        }
    }
    
    private var bannerHeight: CGFloat {
        // Prefer backend-provided height if valid
        if let h = details.height, h > 0 {
            // Scale it down proportionally if it looks like a large image (e.g. 3024)
            // This keeps it visually reasonable on iPhone
            return CGFloat(h) / UIScreen.main.scale / 3
        }
        // Fallback default
        return 120
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 120)
            .overlay(
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            )
    }
    
    private var closeButton: some View {
        Button(action: handleDismiss) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.white, .black.opacity(0.6))
        }
    }
    
    // MARK: - Layout Calculations
    
    private var horizontalPadding: CGFloat {
        let left = parseMargin(details.styling?.marginLeft) ?? 16
        let right = parseMargin(details.styling?.marginRight) ?? 16
        return max(left, right) // Use max for symmetrical padding
    }
    
    private var bottomPadding: CGFloat {
        parseMargin(details.styling?.marginBottom) ?? 60
    }
    
    // Individual corner radius values from backend
    private var topLeftRadius: CGFloat {
        parseRadius(details.styling?.topLeftRadius) ?? 12
    }
    
    private var topRightRadius: CGFloat {
        parseRadius(details.styling?.topRightRadius) ?? 12
    }
    
    private var bottomLeftRadius: CGFloat {
        parseRadius(details.styling?.bottomLeftRadius) ?? 12
    }
    
    private var bottomRightRadius: CGFloat {
        parseRadius(details.styling?.bottomRightRadius) ?? 12
    }
    
    private func parseMargin(_ value: String?) -> CGFloat? {
        guard let value = value, let doubleValue = Double(value) else { return nil }
        return CGFloat(doubleValue)
    }
    
    private func parseRadius(_ value: String?) -> CGFloat? {
        guard let value = value, let doubleValue = Double(value) else { return nil }
        return CGFloat(doubleValue)
    }
    
    // MARK: - Actions

    private func handleTap() {
        Logger.info("🎯 Banner tapped: \(campaignId)")
        
        Task {
            await trackEvent(name: "clicked", metadata: ["action": "banner_tap"])
            
            if let link = details.link, let url = URL(string: link) {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    private func handleDismiss() {
        Logger.info("🚫 Banner dismissed: \(campaignId)")
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        Task {
            await trackEvent(name: "dismissed", metadata: ["action": "user_dismiss"])
            
            await MainActor.run {
                AppStorys.shared.dismissCampaign(campaignId)
            }
        }
    }
    
    // MARK: - Tracking
    
    private func trackViewIfNeeded() {
        guard !hasTrackedView else { return }
        hasTrackedView = true
        
        Task {
            await trackEvent(name: "viewed")
        }
    }
    
    private func trackEvent(name: String, metadata: [String: Any]? = nil) async {
        var eventMetadata = metadata ?? [:]
        eventMetadata["position"] = "bottom"
        eventMetadata["has_close_button"] = details.styling?.enableCloseButton ?? false
        eventMetadata["image_loaded"] = imageLoaded
        
        await AppStorys.shared.trackEvents(
            eventType: name,
            campaignId: campaignId,
            metadata: eventMetadata
        )
    }
}
