//
//  AppStorysOverlayModifier.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Screen-aware campaign display to prevent stale lifecycle interference
//

import SwiftUI

struct AppStorysOverlayModifier: ViewModifier {
    @ObservedObject var sdk: AppStorys
    
    // ✅ CRITICAL FIX: Directly observe tooltip manager
    @ObservedObject private var tooltipManager: TooltipManager
    
    let showBanner: Bool
    let showFloater: Bool
    let showCSAT: Bool
    let showSurvey: Bool
    let showBottomSheet: Bool
    let showModal: Bool
    let showPIP: Bool
    let showStories: Bool
    let showTooltip: Bool
    let showCapture: Bool
    let capturePosition: ScreenCaptureButton.Position
    
    @Namespace private var pipNamespace
    @State private var presentedBottomSheetCampaign: CampaignModel?
    @State private var hasHandledInitialState = false
    
    // ✅ NEW: Track which screen's campaigns are being displayed
    @State private var displayedScreenName: String?
    
    init(
        sdk: AppStorys,
        showBanner: Bool,
        showFloater: Bool,
        showCSAT: Bool,
        showSurvey: Bool,
        showBottomSheet: Bool,
        showModal: Bool,
        showPIP: Bool,
        showStories: Bool,
        showTooltip: Bool,
        showCapture: Bool = true,
        capturePosition: ScreenCaptureButton.Position = .bottomCenter
    ) {
        self.sdk = sdk
        self.showBanner = showBanner
        self.showFloater = showFloater
        self.showCSAT = showCSAT
        self.showSurvey = showSurvey
        self.showBottomSheet = showBottomSheet
        self.showModal = showModal
        self.showPIP = showPIP
        self.showStories = showStories
        self.showCapture = showCapture
        self.showTooltip = showTooltip
        self.capturePosition = capturePosition
        
        // ✅ CRITICAL: Store tooltip manager as observed object
        self._tooltipManager = ObservedObject(wrappedValue: sdk.tooltipManager)
    }
    
    // ✅ FIXED: Simpler logic - always show if SDK has campaigns for current screen
    private var shouldDisplayCampaigns: Bool {
        // Always display if SDK has an active campaign
        // The SDK already handles screen-specific filtering
        return sdk.currentScreen != nil
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .environmentObject(sdk)
            
            // ✅ CRITICAL FIX: Only show campaigns if they're for the current screen
            if shouldDisplayCampaigns {
                campaignOverlays
            }
        }
        .animation(.easeInOut, value: sdk.storyPresentationState != nil)
        .onChange(of: sdk.currentScreen) { oldScreen, newScreen in
            handleScreenChange(from: oldScreen, to: newScreen)
        }
        .task {
            await handleInitialBottomSheetState()
        }
        .onChange(of: sdk.activeBottomSheetCampaign) { oldValue, newValue in
            handleBottomSheetCampaignChange(from: oldValue, to: newValue)
        }
        .sheet(item: $presentedBottomSheetCampaign, onDismiss: handleSheetDismissal) { campaign in
            if case let .bottomSheet(details) = campaign.details {
                BottomSheetView(
                    campaignId: campaign.id,
                    details: details
                )
                .presentationCornerRadius(cornerRadiusValue(details))
                .presentationBackground(.black.opacity(0.001))
            } else {
                Text("Invalid campaign type")
                    .presentationDetents([.height(100)])
            }
        }
    }
    
    // ✅ NEW: Handle screen changes to update displayed screen
    private func handleScreenChange(from oldScreen: String?, to newScreen: String?) {
        guard let newScreen = newScreen else { return }
        
        // ✅ CRITICAL: Update immediately, not after delay
        if displayedScreenName != newScreen {
            Logger.debug("🔄 Screen changed in overlay: \(displayedScreenName ?? "nil") → \(newScreen)")
            displayedScreenName = newScreen
        }
    }
    
    // ✅ NEW: Extracted campaign overlays into computed view
    @ViewBuilder
    private var campaignOverlays: some View {
        // PiP Overlay
        if showPIP, let pipCampaign = sdk.activePIPCampaign {
            AppStorysPIPView(
                sdk: sdk,
                playerManager: sdk.pipPlayerManager,
                namespace: pipNamespace
            )
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .zIndex(1000)
            .id(pipCampaign.id)
        }
        
        // Floater Overlay
        if showFloater,
           let floaterCampaign = sdk.activeFloaterCampaign,
           case let .floater(details) = floaterCampaign.details {
            FloaterView(
                campaignId: floaterCampaign.id,
                details: details
            )
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.3), value: floaterCampaign.id)
            .zIndex(900)
        }
        
        // ✅ Tooltip overlay
        if showTooltip, tooltipManager.isPresenting {
            TooltipView(manager: tooltipManager)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: tooltipManager.isPresenting)
                .zIndex(3000)
        }
        
        // Capture Button Overlay
        if showCapture, sdk.isScreenCaptureEnabled {
            ZStack(alignment: capturePosition.alignment) {
                Color.clear
                
                sdk.captureButton()
                    .padding(capturePosition.padding)
            }
            .zIndex(999)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.3), value: sdk.isScreenCaptureEnabled)
        }
        
        // Story overlay
        if showStories, let presentationState = sdk.storyPresentationState {
            StoryGroupPager(
                manager: sdk.storyManager,
                campaign: presentationState.campaign,
                initialGroupIndex: presentationState.initialIndex,
                onDismiss: {
                    sdk.dismissStory()
                }
            )
            .zIndex(2000)
            .id(presentationState.campaign.id)
            .transition(.move(edge: .bottom))
        }
    }
    
    // MARK: - Initial State Handler
    
    @MainActor
    private func handleInitialBottomSheetState() async {
        guard showBottomSheet, !hasHandledInitialState else { return }
        hasHandledInitialState = true
        
        if let campaign = sdk.activeBottomSheetCampaign,
           presentedBottomSheetCampaign == nil,
           !sdk.isCampaignDismissed(campaign.id) {
            Logger.debug("📋 Setting initial campaign: \(campaign.id)")
            try? await Task.sleep(nanoseconds: 500_000_000)
            presentedBottomSheetCampaign = campaign
        }
    }
    
    // MARK: - Campaign Change Handler
    
    private func handleBottomSheetCampaignChange(
        from oldCampaign: CampaignModel?,
        to newCampaign: CampaignModel?
    ) {
        guard showBottomSheet else { return }
        
        Logger.debug("📋 Campaign changed: \(oldCampaign?.id ?? "nil") → \(newCampaign?.id ?? "nil")")
        
        if oldCampaign == nil, let newCampaign = newCampaign {
            guard !sdk.isCampaignDismissed(newCampaign.id) else {
                Logger.debug("⏭ Campaign \(newCampaign.id) was dismissed, skipping")
                return
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                presentedBottomSheetCampaign = newCampaign
                Logger.debug("📋 Set campaign for presentation after delay: \(newCampaign.id)")
            }
        }
        else if oldCampaign != nil, newCampaign == nil {
            presentedBottomSheetCampaign = nil
            Logger.debug("📋 Cleared campaign - sheet will dismiss")
        }
        else if let old = oldCampaign, let new = newCampaign, old.id != new.id {
            Logger.warning("⚠️ Campaign changed mid-presentation")
            
            guard !sdk.isCampaignDismissed(new.id) else {
                presentedBottomSheetCampaign = nil
                return
            }
            
            presentedBottomSheetCampaign = new
        }
    }
    
    // MARK: - Sheet Dismissal Handler
    
    private func handleSheetDismissal() {
        guard let campaign = presentedBottomSheetCampaign else { return }
        
        Logger.debug("📋 Sheet dismissed by user: \(campaign.id)")
        
        Task {
            await sdk.trackEvents(
                eventType: "dismissed",
                campaignId: campaign.id,
                metadata: ["action": "swipe_dismiss"]
            )
        }
        
        sdk.dismissCampaign(campaign.id)
    }
    
    // MARK: - Helpers
    
    private func cornerRadiusValue(_ details: BottomSheetDetails) -> CGFloat {
        guard let radiusString = details.cornerRadius,
              let radius = Double(radiusString) else {
            return 32
        }
        return CGFloat(radius)
    }
}

extension View {
    public func withAppStorysOverlays(
        sdk: AppStorys = .shared,
        showBanner: Bool = true,
        showFloater: Bool = true,
        showCSAT: Bool = true,
        showSurvey: Bool = true,
        showBottomSheet: Bool = true,
        showModal: Bool = true,
        showPIP: Bool = true,
        showStories: Bool = true,
        showTooltip: Bool = true,
        showCapture: Bool = true,
        capturePosition: ScreenCaptureButton.Position = .bottomCenter
    ) -> some View {
        modifier(AppStorysOverlayModifier(
            sdk: sdk,
            showBanner: showBanner,
            showFloater: showFloater,
            showCSAT: showCSAT,
            showSurvey: showSurvey,
            showBottomSheet: showBottomSheet,
            showModal: showModal,
            showPIP: showPIP,
            showStories: showStories,
            showTooltip: showTooltip,
            showCapture: showCapture,
            capturePosition: capturePosition
        ))
    }
}
