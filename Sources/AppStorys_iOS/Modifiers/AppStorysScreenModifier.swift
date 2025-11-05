//
//  AppStorysScreenModifier.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Proper integration with ScreenCaptureManager.captureAndUpload
//

import SwiftUI
import UIKit

// MARK: - Screen Modifier with Snapshot Support

struct AppStorysScreenModifier: ViewModifier {
    let screenName: String
    let onCampaignsLoaded: ([CampaignModel]) -> Void
    
    @StateObject private var sdk = AppStorys.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var triggerSnapshot = false
     
    func body(content: Content) -> some View {
        content
            // ✅ Capture context overlay
            .overlay(
                CaptureContextProviderView()
                    .allowsHitTesting(false)
            )
            // ✅ Listen for snapshot trigger
            .onReceive(NotificationCenter.default.publisher(for: .AppStorysTriggerSnapshot)) { notification in
                guard let info = notification.userInfo as? [String: Any],
                      let requestedScreen = info["screen"] as? String,
                      requestedScreen == screenName else { return }
                
                Logger.debug("📸 Received snapshot trigger for \(screenName)")
                triggerSnapshot = true
            }
            // ✅ SwiftUI Snapshot Integration
            .snapshot(trigger: triggerSnapshot) { image in
                Task {
                    guard let userId = sdk.currentUserID,
                          let captureManager = sdk.screenCaptureManager else {
                        Logger.warning("⚠️ Cannot upload snapshot - SDK not ready")
                        triggerSnapshot = false
                        return
                    }
                    
                    // ✅ Get the root view for element discovery
                    guard let rootView = try? sdk.getCaptureView() else {
                        Logger.error("❌ Cannot get root view for capture")
                        triggerSnapshot = false
                        return
                    }
                    
                    Logger.info("📤 Processing SwiftUI snapshot for \(screenName)")
                    
                    do {
                        try await captureManager.uploadSwiftUISnapshot(image, screenName: screenName, userId: userId)
                        Logger.info("✅ SwiftUI snapshot uploaded successfully")
                    } catch {
                        Logger.error("❌ Failed to upload SwiftUI snapshot: \(error)")
                    }
                    
                    triggerSnapshot = false
                }
            }
            // ✅ Lifecycle tracking
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

                // 🧹 NEW: Clear capture context if this screen owned it
                if sdk.currentScreen == screenName {
                    Logger.debug("🧹 Clearing capture context (screen \(screenName) no longer visible)")
                    sdk.clearCaptureContext()
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

// MARK: - ✅ SwiftUI Snapshot Implementation (from article)

fileprivate struct SnapshotModifier: ViewModifier {
    var trigger: Bool
    var onComplete: (UIImage) -> ()
    @State private var view: UIView = .init(frame: .zero)
    
    func body(content: Content) -> some View {
        content
            .background(ViewExtractor(view: view))
            .compositingGroup()
            .onChange(of: trigger) { oldValue, newValue in
                if newValue {
                    generateSnapshot()
                }
            }
    }
    
    private func generateSnapshot() {
        if let superView = view.superview?.superview {
            let render = UIGraphicsImageRenderer(size: superView.bounds.size)
            let image = render.image { _ in
                superView.drawHierarchy(in: superView.bounds, afterScreenUpdates: true)
            }
            onComplete(image)
        }
    }
}

fileprivate struct ViewExtractor: UIViewRepresentable {
    var view: UIView
    
    func makeUIView(context: Context) -> UIView {
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // no process
    }
}

extension View {
    @ViewBuilder
    fileprivate func snapshot(trigger: Bool, onComplete: @escaping (UIImage) -> ()) -> some View {
        self.modifier(SnapshotModifier(trigger: trigger, onComplete: onComplete))
    }
}

// MARK: - Capture Context Provider

private struct CaptureContextProviderView: UIViewRepresentable {
    @EnvironmentObject private var sdk: AppStorys
    
    func makeUIView(context: Context) -> CaptureContextUIView {
        let view = CaptureContextUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: CaptureContextUIView, context: Context) {
        if let contentView = uiView.findActualContentView() {
            sdk.setCaptureContext(contentView)
            Logger.debug("✅ Capture context set: \(type(of: contentView))")
        } else {
            Logger.warning("⚠️ Could not find content view for capture context")
        }
    }
}

// MARK: - Safe View Finder Logic

private class CaptureContextUIView: UIView {
    func findActualContentView() -> UIView? {
        Logger.debug("🔍 Searching for actual content view...")
        
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
            
            if viewType.contains("HostingView") {
                score += 80
                Logger.debug("      🎯 HostingView found!")
            }
            if viewType.contains("PlatformViewHost") && !viewType.contains("CaptureContext") {
                score += 70
                Logger.debug("      🎯 PlatformViewHost found!")
            }
            if viewType.contains("UIView") && view.subviews.count > 3 {
                score += 50
            }
            if view.subviews.count > 5 {
                score += 20
            }
            if view.subviews.count > 10 {
                score += 10
            }
            if viewType.contains("CaptureContext") {
                score -= 100
                Logger.debug("      ⚠️ Skipping bridge container")
            }
            if viewType.contains("TabBar") {
                score -= 50
                Logger.debug("      ⚠️ Avoiding TabBar view")
            }
            if viewType.contains("Controller") {
                score = 0
                Logger.debug("      ⚠️ Skipping controller-related view")
            }
            
            if score > 0 {
                candidateViews.append((view, score, depth))
            }
            
            currentView = view.superview
            depth += 1
        }
        
        if let best = candidateViews.max(by: { $0.score < $1.score }) {
            let viewType = String(describing: type(of: best.view))
            Logger.debug("✅ Selected content view: \(viewType) (score: \(best.score), depth: \(best.depth))")
            
            if !viewType.contains("Controller") && !viewType.contains("TabBar") {
                return best.view
            } else {
                Logger.warning("⚠️ Selected view looks unsafe, using fallback")
            }
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.keyWindow {
            Logger.warning("⚠️ Using key window as fallback")
            return keyWindow
        }
        
        Logger.error("❌ Could not find any suitable content view!")
        return nil
    }
}

// MARK: - Public Extension

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

// MARK: - Notification Name Extension

extension Notification.Name {
    static let AppStorysTriggerSnapshot = Notification.Name("AppStorysTriggerSnapshot")
}
