//
//  CaptureContextProvider.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 16/10/25.
//


//
//  CaptureContext.swift
//  AppStorys_iOS
//
//  Captures the actual current view, not root window
//

import SwiftUI
import UIKit

// MARK: - Capture Context Provider

/// Provides the current UIView for screen capture
@MainActor
class CaptureContextProvider: ObservableObject {
    weak var currentView: UIView?
    
    func setView(_ view: UIView) {
        self.currentView = view
        Logger.debug("📱 Capture context updated: \(type(of: view))")
    }
}

// MARK: - View Extension for Capture Context

extension View {
    /// Makes this view capturable by providing its UIView to the SDK
    /// 
    /// Usage:
    /// ```swift
    /// var body: some View {
    ///     YourScreen()
    ///         .captureContext()  // ← Add this
    ///         .withAppStorysOverlays()
    /// }
    /// ```
    public func captureContext() -> some View {
        background(CaptureContextView())
    }
}

// MARK: - Internal Implementation

private struct CaptureContextView: UIViewRepresentable {
    @EnvironmentObject private var sdk: AppStorys
    
    func makeUIView(context: Context) -> CaptureContextUIView {
        let view = CaptureContextUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: CaptureContextUIView, context: Context) {
        // Find the hosting view (the actual content view)
        if let hostingView = uiView.findHostingView() {
            sdk.setCaptureContext(hostingView)
        }
    }
}

private class CaptureContextUIView: UIView {
    /// Find the SwiftUI hosting view (the actual content container)
    func findHostingView() -> UIView? {
        // Traverse up to find the hosting controller's view
        var currentView: UIView? = self.superview
        
        while let view = currentView {
            // Check if this is a hosting view (contains actual content)
            let viewType = String(describing: type(of: view))
            
            if viewType.contains("HostingView") || 
               viewType.contains("UIHostingController") {
                Logger.debug("✅ Found hosting view: \(viewType)")
                return view
            }
            
            currentView = view.superview
        }
        
        // Fallback: use the direct superview
        Logger.warning("⚠️ No hosting view found, using superview")
        return self.superview
    }
}

// MARK: - AppStorys Extension

extension AppStorys {
    private static var captureContext: CaptureContextProvider = CaptureContextProvider()
    
    /// Set the current view for capture
    func setCaptureContext(_ view: UIView) {
        Self.captureContext.currentView = view
    }
    
    /// Get the current capturable view
    func getCaptureView() throws -> UIView {
        // Try context view first
        if let contextView = Self.captureContext.currentView {
            Logger.debug("📸 Using context view: \(type(of: contextView))")
            return contextView
        }
        
        // Fallback to key window
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.keyWindow ?? scene.windows.first else {
            Logger.error("❌ No window available for capture")
            throw ScreenCaptureError.noActiveScreen
        }
        
        Logger.warning("⚠️ Using fallback window capture - add .captureContext() to your view!")
        return window
    }
    
    /// Updated capture method using context
    public func captureScreen() async throws {
        guard isInitialized else {
            throw AppStorysError.notInitialized
        }
        
        guard isScreenCaptureEnabled else {
            Logger.warning("⚠️ Screen capture is disabled by server")
            throw ScreenCaptureError.featureDisabled
        }
        
        guard let manager = screenCaptureManager else {
            Logger.error("❌ Screen capture manager not initialized")
            throw ScreenCaptureError.managerNotInitialized
        }
        
        guard let userId = currentUserID else {
            throw AppStorysError.notInitialized
        }
        
        guard let screenName = currentScreen else {
            Logger.warning("⚠️ No active screen to capture")
            throw ScreenCaptureError.noActiveScreen
        }
        
        // ✅ Get the CURRENT view, not root window
        let view = try getCaptureView()
        
        Logger.info("📸 Capturing screen: \(screenName) from \(type(of: view))")
        
        try await manager.captureAndUpload(
            screenName: screenName,
            userId: userId,
            rootView: view
        )
    }
}