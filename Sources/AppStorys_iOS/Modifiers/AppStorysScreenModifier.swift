//
//  AppStorysScreenModifier.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Screen-aware dismissal to prevent race conditions
//

import SwiftUI

struct AppStorysScreenModifier: ViewModifier {
    let screenName: String
    let onCampaignsLoaded: ([CampaignModel]) -> Void
    
    @StateObject private var sdk = AppStorys.shared
    @Environment(\.scenePhase) private var scenePhase
    
    func body(content: Content) -> some View {
        content
            .captureContext()
            .onAppear {
                Logger.debug("📺 Screen appeared: \(screenName)")
                sdk.trackScreen(screenName, completion: onCampaignsLoaded)
            }
            .onDisappear {
                Logger.debug("👋 Screen disappeared: \(screenName)")
                
                // ✅ CRITICAL FIX: Use screen-aware dismissal
                if scenePhase == .active {
                    Logger.info("💤 Screen inactive - checking if campaigns should hide")
                    
                    // Only hide campaigns if this screen is STILL the current screen
                    // This prevents stale .onDisappear from killing new screen's campaigns
                    sdk.handleScreenDisappeared(screenName)
                    
                    // Mark as inactive but keep cache for back navigation
                    sdk.campaignRepository.markScreenInactive(screenName)
                } else {
                    Logger.info("🌙 App backgrounded - preserving everything")
                }
            }
    }
}

extension View {
    public func trackAppStorysScreen(
        _ screenName: String,
        onCampaignsLoaded: @escaping ([CampaignModel]) -> Void = { _ in }
    ) -> some View {
        modifier(AppStorysScreenModifier(
            screenName: screenName,
            onCampaignsLoaded: onCampaignsLoaded
        ))
    }
}
