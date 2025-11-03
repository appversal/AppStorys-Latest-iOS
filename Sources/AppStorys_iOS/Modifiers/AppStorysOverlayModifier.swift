//
//  AppStorysOverlayModifier.swift
//  AppStorys_iOS
//
//  âœ… COMPLETE: Fixed dismissal animation
//

import SwiftUI

struct AppStorysOverlayModifier: ViewModifier {
    @ObservedObject var sdk: AppStorys
    
    let showBanner: Bool
    let showFloater: Bool
    let showCSAT: Bool
    let showSurvey: Bool
    let showBottomSheet: Bool
    let showModal: Bool
    let showPIP: Bool
    let showStories: Bool
    let showCapture: Bool
    let capturePosition: ScreenCaptureButton.Position
    
    @Namespace private var pipNamespace
    
    // âœ… NEW: Track dismissal animation state
    @State private var isAnimatingStoryDismissal = false
    
    init(
        sdk: AppStorys,
        showBanner: Bool,
        showFloater: Bool,
        showCSAT: Bool,
        showSurvey: Bool,
        showBottomSheet: Bool,
        showModal: Bool,
        showPIP: Bool = true,
        showStories: Bool = true,
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
        self.capturePosition = capturePosition
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .environmentObject(sdk)
            
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
                .animation(.easeOut(duration: 0.2), value: pipCampaign.id)
                .id(pipCampaign.id)
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
            
            // Story overlay with smooth animations
            if showStories,
               let presentationState = sdk.storyPresentationState,
               !isAnimatingStoryDismissal {
                
                StoryGroupPager(
                    manager: sdk.storyManager,
                    campaign: presentationState.campaign,
                    initialGroupIndex: presentationState.initialIndex,
                    onDismiss: {
                        // âœ… Animate dismissal state first
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isAnimatingStoryDismissal = true
                        }
                        
                        // âœ… Then dismiss after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            sdk.dismissStory()
                            isAnimatingStoryDismissal = false
                        }
                    }
                )
                .zIndex(2000)
                .id(presentationState.campaign.id)
            }
        }
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
            showCapture: showCapture,
            capturePosition: capturePosition
        ))
    }
}
