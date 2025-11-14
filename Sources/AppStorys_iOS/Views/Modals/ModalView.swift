//
//  ModalView.swift
//  AppStorys_iOS
//
//
//
//

import SwiftUI

public struct ModalView: View {
    
    let sdk: AppStorys
    let campaignId: String
    let details: ModalDetails
    
    // MARK: - State
    
    @State private var isVisible = false
    @State private var selectedModalIndex = 0
    @State private var hasTrackedView = false
    
    // Dismiss animation state
    @State private var isDismissing = false
    
    // MARK: - Initialization
    
    public init(sdk: AppStorys, campaignId: String, details: ModalDetails) {
        self.sdk = sdk
        self.campaignId = campaignId
        self.details = details
    }
    
    // MARK: - Body
    
    public var body: some View {
        if let modal = details.modals[safe: selectedModalIndex] {
            ZStack {
                // Backdrop with configurable opacity
                Color.black
                    .opacity(isDismissing ? 0 : modal.backdropOpacity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        handleDismiss(reason: "backdrop_tap")
                    }
                    .animation(.easeOut(duration: 0.25), value: isDismissing)
                
                modalContent(modal)
                
                    .frame(width: modal.modalSize, height: modal.modalSize)
                    .clipShape(RoundedRectangle(cornerRadius: modal.cornerRadius, style: .continuous))
                    .overlay(
                        HStack {
                            Spacer()
                            closeButton
                        }
                            .offset(x: 8, y: -20)
                            .opacity(isVisible && !isDismissing ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.2).delay(0.3), value: isVisible)
                        
                        ,alignment: .topLeading
                    )
                    .scaleEffect(scaleValue)
                    .opacity(opacityValue)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
                    .animation(.spring(response: 0.3, dampingFraction: 0.9), value: isDismissing)
                
            }
            .onAppear {
                handleAppear()
            }
        } else {
            // Graceful degradation for empty modals array
            EmptyView()
                .onAppear {
                    Logger.error("❌ Modal campaign has no modal items")
                    
                    Task { [weak sdk] in
                        await sdk?.trackEvents(
                            eventType: "error",
                            campaignId: campaignId,
                            metadata: ["reason": "no_modal_items"]
                        )
                    }
                }
        }
    }
    
    // MARK: - Computed Animation Values
    
    private var scaleValue: CGFloat {
        if isDismissing {
            return 0.8
        }
        return isVisible ? 1.0 : 0.8
    }
    
    private var opacityValue: Double {
        if isDismissing {
            return 0.0
        }
        return isVisible ? 1.0 : 0.0
    }
    
    // MARK: - Modal Content
    
    @ViewBuilder
    private func modalContent(_ modal: ModalItem) -> some View {
        if let imageURL = modal.imageURL {
            AppStorysImageView(
                url: imageURL,
                contentMode: .fill,
                showShimmer: true,
                cornerRadius: modal.cornerRadius,
                onSuccess: {
                    Logger.debug("✅ Modal image loaded: \(modal.name)")
                },
                onFailure: { error in
                    Logger.error("❌ Modal image failed", error: error)
                    
                    Task { [weak sdk] in
                        await sdk?.trackEvents(
                            eventType: "image_load_failed",
                            campaignId: campaignId,
                            metadata: [
                                "modal_name": modal.name,
                                "url": imageURL.absoluteString
                            ]
                        )
                    }
                }
            )
            .contentShape(Rectangle()) // Ensure full tappable area
            .onTapGesture {
                handleModalTap(modal)
            }
        } else {
            // Fallback for missing image URL
            fallbackView
        }
    }
    
    // MARK: - Fallback View
    
    private var fallbackView: some View {
        ZStack {
            Color.gray.opacity(0.1)
            
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.6))
                
                Text("Image not available")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        Button(action: {
            handleDismiss(reason: "close_button")
        }) {
            Image(systemName: "xmark")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.thinMaterial))
        }
        .accessibilityLabel("Close modal")
        .accessibilityHint("Double tap to dismiss")
    }
    
    // MARK: - Actions
    
    private func handleAppear() {
        // Track view event once
        if !hasTrackedView {
            hasTrackedView = true
            
            Task { [weak sdk] in
                await sdk?.trackEvents(
                    eventType: "viewed",
                    campaignId: campaignId,
                    metadata: [
                        "modal_name": details.modals[safe: selectedModalIndex]?.name ?? "unknown",
                        "screen": sdk?.currentScreen ?? "unknown"
                    ]
                )
            }
        }
        
        // Animate in with slight delay for better perception
        Task {
//            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            await MainActor.run {
                withAnimation {
                    isVisible = true
                }
            }
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func handleModalTap(_ modal: ModalItem) {
        guard let url = modal.destinationURL else {
            Logger.warning("⚠️ Modal '\(modal.name)' has no destination URL")
            return
        }
        
        Logger.info("🔗 Modal tapped: \(modal.name) → \(url.absoluteString)")
        
        // Track click
        Task { [weak sdk] in
            await sdk?.trackEvents(
                eventType: "clicked",
                campaignId: campaignId,
                metadata: [
                    "action": "modal_tap",
                    "modal_name": modal.name,
                    "url": url.absoluteString
                ]
            )
        }
        
        // Open URL
        UIApplication.shared.open(url)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Dismiss after brief delay
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            await MainActor.run {
                handleDismiss(reason: "navigated")
            }
        }
    }
    
    private func handleDismiss(reason: String) {
        guard !isDismissing else {
            Logger.debug("⏭ Already dismissing")
            return
        }
        
        Logger.debug("❌ Dismissing modal: \(reason)")
        
        // Start dismiss animation
        isDismissing = true
        
        // Track dismissal
        Task { [weak sdk] in
            await sdk?.trackEvents(
                eventType: "dismissed",
                campaignId: campaignId,
                metadata: [
                    "reason": reason,
                    "modal_name": details.modals[safe: selectedModalIndex]?.name ?? "unknown"
                ]
            )
        }
        
        // Remove from SDK state after animation
        Task { [weak sdk] in
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s (match animation duration)
            await MainActor.run {
                sdk?.dismissCampaign(campaignId)
            }
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview Support

#if DEBUG
struct ModalView_Previews: PreviewProvider {
    static var previews: some View {
        let mockSDK = AppStorys.shared
        
        let mockDetails = ModalDetails(
            id: "preview-id",
            modals: [
                ModalItem(
                    backgroundOpacity: "0.7",
                    borderRadius: "24",
                    link: "https://example.com",
                    name: "Preview Modal",
                    redirection: nil,
                    size: "300",
                    url: "https://picsum.photos/300/300"
                )
            ],
            name: "Preview"
        )
        
        ModalView(
            sdk: mockSDK,
            campaignId: "preview-campaign",
            details: mockDetails
        )
    }
}
#endif
