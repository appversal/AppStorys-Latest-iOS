//
//  AppStorysScreenModifier.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 17/10/25.
//


//
//  AppStorysScreenModifier.swift
//  AppStorys_iOS
//
//  Automatic screen tracking and cleanup
//

import SwiftUI

// MARK: - Screen Lifecycle Modifier

struct AppStorysScreenModifier: ViewModifier {
    let screenName: String
    let onCampaignsLoaded: ([CampaignModel]) -> Void
    
    @StateObject private var sdk = AppStorys.shared
    
    func body(content: Content) -> some View {
        content
            .captureContext()  // ✅ Auto-add capture context
            .onAppear {
                print("📺 Screen appeared: \(screenName)")
                sdk.trackScreen(screenName, completion: onCampaignsLoaded)
            }
            .onDisappear {
                print("👋 Screen disappeared: \(screenName)")
                sdk.hideAllCampaigns()
            }
    }
}

// MARK: - View Extension

extension View {
    /// Track this screen with AppStorys and automatically handle lifecycle
    ///
    /// Usage:
    /// ```swift
    /// var body: some View {
    ///     YourContent()
    ///         .trackAppStorysScreen("Home Screen")
    /// }
    /// ```
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
