//
//  AppStorysOverlayModifier.swift
//  AppStorys_iOS
//
//  ✅ SAFE: Crash-proof tooltip observer with dynamic SDK binding
//

import Combine
import SwiftUI

@MainActor
final class TooltipObserver: ObservableObject {
    @Published var manager: TooltipManager?
    private var sdkObserver: AnyCancellable?

    init(sdk: AppStorys) {
        self.manager = sdk.tooltipManager

        // ✅ Ensure subscription runs on main actor
        self.sdkObserver = sdk.$tooltipManager
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newManager in
                self?.manager = newManager
                Logger.debug("🎯 Tooltip observer updated — manager: \(newManager != nil)")
            }
    }
}

// MARK: - Main Modifier

struct AppStorysOverlayModifier: ViewModifier {
    @ObservedObject var sdk: AppStorys
    @StateObject private var tooltipObserver: TooltipObserver

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
    @State private var displayedScreenName: String?

    // MARK: - Init

    init(
        sdk: AppStorys,
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
    ) {
        self.sdk = sdk
        _tooltipObserver = StateObject(wrappedValue: TooltipObserver(sdk: sdk))
        self.showBanner = showBanner
        self.showFloater = showFloater
        self.showCSAT = showCSAT
        self.showSurvey = showSurvey
        self.showBottomSheet = showBottomSheet
        self.showModal = showModal
        self.showPIP = showPIP
        self.showStories = showStories
        self.showTooltip = showTooltip
        self.showCapture = showCapture
        self.capturePosition = capturePosition
    }

    // MARK: - Core Body

    func body(content: Content) -> some View {
        ZStack {
            content
                .environmentObject(sdk)

            if sdk.currentScreen != nil {
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
                .presentationBackground(.clear)
            } else {
                Text("Invalid campaign type")
                    .presentationDetents([.height(100)])
            }
        }
    }

    // MARK: - Overlays
    @ViewBuilder
    private var campaignOverlays: some View {
        // Banner Overlay
        if showBanner,
           let bannerCampaign = sdk.activeBannerCampaign,
           case let .banner(details) = bannerCampaign.details {
            BannerView(
                campaignId: bannerCampaign.id,
                details: details
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4), value: bannerCampaign.id)
            .zIndex(800)
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
        
        // Modal Overlay
        if showModal,
           let modalCampaign = sdk.activeModalCampaign,
           case let .modal(details) = modalCampaign.details {
            ModalView(
                sdk: sdk,  // ✅ CRITICAL: Pass SDK directly
                campaignId: modalCampaign.id,
                details: details
            )
            .transition(.opacity.combined(with: .scale))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: modalCampaign.id)
            .zIndex(1500)
        }
        
        // ✅ Tooltip Overlay (reactive + crash-safe)
        if showTooltip,
           sdk.isInitialized,
           let manager = tooltipObserver.manager {

            TooltipOverlayContainer(manager: manager)
                .zIndex(3000)
        }

        // Capture Button Overlay (safe version)
        if showCapture,
           sdk.isScreenCaptureEnabled,
           let currentScreen = sdk.currentScreen,
           sdk.captureContextProvider.currentView != nil {
            
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

    private struct TooltipOverlayContainer: View {
        @ObservedObject var manager: TooltipManager
        @State private var isVisible = false

        var body: some View {
            ZStack {
                if isVisible {
                    TooltipView(manager: manager)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.25), value: isVisible)
                        .id("tooltip_\(manager.currentStep)")
                }
            }
            // 👇 This makes SwiftUI react directly to @Published isPresenting
            .onReceive(manager.$isPresenting.receive(on: DispatchQueue.main)) { newValue in
                isVisible = newValue
                Logger.debug("🎯 TooltipOverlayContainer — isPresenting changed to \(newValue)")
            }
        }
    }


    // MARK: - Handlers

    private func handleScreenChange(from oldScreen: String?, to newScreen: String?) {
        guard let newScreen = newScreen else { return }
        if displayedScreenName != newScreen {
            Logger.debug("🔄 Screen changed in overlay: \(displayedScreenName ?? "nil") → \(newScreen)")
            displayedScreenName = newScreen
        }
    }

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

    private func handleBottomSheetCampaignChange(from oldCampaign: CampaignModel?, to newCampaign: CampaignModel?) {
        guard showBottomSheet else { return }
        Logger.debug("📋 Campaign changed: \(oldCampaign?.id ?? "nil") → \(newCampaign?.id ?? "nil")")

        if oldCampaign == nil, let newCampaign = newCampaign {
            guard !sdk.isCampaignDismissed(newCampaign.id) else {
                Logger.debug("⏭ Campaign \(newCampaign.id) dismissed, skipping")
                return
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                presentedBottomSheetCampaign = newCampaign
                Logger.debug("📋 Presenting new campaign after delay: \(newCampaign.id)")
            }
        } else if oldCampaign != nil, newCampaign == nil {
            presentedBottomSheetCampaign = nil
            Logger.debug("📋 Cleared campaign — sheet dismissed")
        }
    }

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

    private func cornerRadiusValue(_ details: BottomSheetDetails) -> CGFloat {
        guard let radiusString = details.cornerRadius,
              let radius = Double(radiusString) else { return 32 }
        return CGFloat(radius)
    }
}

// MARK: - View Extension

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
        modifier(
            AppStorysOverlayModifier(
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
            )
        )
    }
}
