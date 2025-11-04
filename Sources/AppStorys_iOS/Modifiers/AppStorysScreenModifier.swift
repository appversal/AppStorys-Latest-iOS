//
//  AppStorysScreenModifier.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Proper capture context targeting actual content
//

import SwiftUI

// MARK: - Screen Modifier (unchanged)

struct AppStorysScreenModifier: ViewModifier {
    let screenName: String
    let onCampaignsLoaded: ([CampaignModel]) -> Void
    
    @StateObject private var sdk = AppStorys.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            // ✅ CRITICAL: Apply capture context first
            .background(
                CaptureContextProviderView()
            )
            .onAppear {
                isVisible = true
                Logger.debug("📺 Screen appeared: \(screenName)")
                sdk.trackScreen(screenName, completion: onCampaignsLoaded)
            }
            .onDisappear {
                isVisible = false
                Logger.debug("👋 Screen disappeared: \(screenName)")
                
                if scenePhase == .active {
                    Logger.info("💤 Screen inactive - checking if campaigns should hide")
                    sdk.handleScreenDisappeared(screenName)
                    sdk.campaignRepository.markScreenInactive(screenName)
                } else {
                    Logger.info("🌙 App backgrounded - preserving everything")
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active && isVisible {
                    Logger.debug("♻️ App returned to foreground on \(screenName)")
                    sdk.trackScreen(screenName, completion: onCampaignsLoaded)
                }
            }
    }
}

// MARK: - ✅ FIXED: Capture Context Provider

private struct CaptureContextProviderView: UIViewRepresentable {
    @EnvironmentObject private var sdk: AppStorys
    
    func makeUIView(context: Context) -> CaptureContextUIView {
        let view = CaptureContextUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: CaptureContextUIView, context: Context) {
        // Find the actual content view (not the bridge itself)
        if let contentView = uiView.findActualContentView() {
            sdk.setCaptureContext(contentView)
            Logger.debug("✅ Capture context set: \(type(of: contentView))")
        } else {
            Logger.warning("⚠️ Could not find content view for capture context")
        }
    }
}

// MARK: - ✅ FIXED: View Finder Logic

private class CaptureContextUIView: UIView {
    
    /// Find the actual content view (not the bridge's container)
    func findActualContentView() -> UIView? {
        Logger.debug("🔍 Searching for actual content view...")
        
        // Strategy: Go UP the hierarchy to find content containers
        var currentView: UIView? = self.superview
        var depth = 0
        let maxDepth = 15
        
        var candidateViews: [(view: UIView, score: Int, depth: Int)] = []
        
        while let view = currentView, depth < maxDepth {
            let viewType = String(describing: type(of: view))
            
            if depth < 8 {
                Logger.debug("   [\(depth)] \(viewType)")
            }
            
            var score = 0
            
            // ✅ SCORING SYSTEM: Find the best content container
            
            // HIGH PRIORITY: Navigation/Tab containers (these hold the actual content)
            if viewType.contains("UITabBarController") {
                score += 100
                Logger.debug("      🎯 TabBarController found!")
            }
            if viewType.contains("UINavigationController") {
                score += 90
                Logger.debug("      🎯 NavigationController found!")
            }
            if viewType.contains("NavigationStackHosting") {
                score += 85
                Logger.debug("      🎯 NavigationStackHosting found!")
            }
            
            // MEDIUM PRIORITY: Content views
            if viewType.contains("HostingController") {
                score += 70
            }
            if viewType.contains("PlatformViewHost") && !viewType.contains("CaptureContext") {
                score += 60
            }
            if viewType.contains("UIView") && view.subviews.count > 2 {
                score += 50 // Likely a content container
            }
            
            // BONUS: View has actual content
            if view.subviews.count > 5 {
                score += 20
            }
            
            // PENALTY: Avoid bridge containers
            if viewType.contains("CaptureContext") {
                score -= 100
                Logger.debug("      ⚠️ Skipping bridge container")
            }
            
            if score > 0 {
                candidateViews.append((view, score, depth))
            }
            
            currentView = view.superview
            depth += 1
        }
        
        // ✅ Select best candidate
        if let best = candidateViews.max(by: { $0.score < $1.score }) {
            let viewType = String(describing: type(of: best.view))
            Logger.debug("✅ Selected content view: \(viewType) (score: \(best.score), depth: \(best.depth))")
            return best.view
        }
        
        // ✅ Fallback 1: Try UITabBarController directly
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.keyWindow,
           let tabBarController = keyWindow.rootViewController as? UITabBarController {
            Logger.debug("✅ Using UITabBarController as fallback")
            return tabBarController.view
        }
        
        // ✅ Fallback 2: Key window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.keyWindow {
            Logger.warning("⚠️ Using key window as last resort")
            return keyWindow
        }
        
        Logger.error("❌ Could not find any suitable content view!")
        return nil
    }
}

// MARK: - Public Extension

extension View {
    /// Track this screen with AppStorys
    /// - Parameters:
    ///   - screenName: Name to identify this screen
    ///   - onCampaignsLoaded: Callback when campaigns are loaded for this screen
    ///
    /// ✅ Usage:
    /// ```swift
    /// NavigationStack {
    ///     MyScreenContent()
    /// }
    /// .trackAppStorysScreen("My Screen")
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
