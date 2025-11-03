//
//  CaptureTagBridge.swift
//  AppStorys_iOS
//
//  Fixed: Removed window.first logic
//

import SwiftUI
import UIKit

// MARK: - Public Screen Capture API

extension AppStorys {
    
    /// Create a capture button that handles everything automatically
    /// Usage: sdk.captureButton()
    @MainActor
    public func captureButton() -> some View {
        ScreenCaptureButton {
            // ✅ Uses new captureScreen() method with context
            try await self.captureScreen()
        }
    }
}

// MARK: - Public Tagging Extension

extension View {
    /// Tag a view for screen capture
    /// This fixes SwiftUI's accessibility identifier not working with UIKit
    ///
    /// Usage:
    /// ```swift
    /// Text("Hello")
    ///     .captureTag("hello_text")
    /// ```
    public func captureAppStorysTag(_ identifier: String) -> some View {
        let prefixedId = "APPSTORYS_\(identifier)"
        return self.background(
            CaptureTagBridge(identifier: prefixedId)
        )
    }
}

// MARK: - Internal Bridge

private struct CaptureTagBridge: UIViewRepresentable {
    let identifier: String
    
    func makeUIView(context: Context) -> CaptureTagView {
        let view = CaptureTagView()
        view.accessibilityIdentifier = identifier
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: CaptureTagView, context: Context) {
        uiView.accessibilityIdentifier = identifier
    }
}

private class CaptureTagView: UIView {
    override var accessibilityIdentifier: String? {
        didSet {
            // Just store it normally
        }
    }
}
