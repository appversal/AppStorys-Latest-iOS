//
//  CaptureContextProvider.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Properly detects NavigationStack content vs TabView root
//

import SwiftUI
import UIKit

// MARK: - Capture Context Provider

@MainActor
class CaptureContextProvider: ObservableObject {
    weak var currentView: UIView?
    
    func setView(_ view: UIView) {
        self.currentView = view
        let viewType = String(describing: type(of: view))
        let frame = view.frame
        Logger.debug("📱 Capture context updated: \(viewType) frame: \(frame)")
    }
}

// MARK: - View Extension for Capture Context

extension View {
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
        // 🚫 Skip global context updates when no tracked screen is active
        guard sdk.currentScreen != nil else {
            if Self.lastLoggedNilContext != true {
                Logger.debug("🚫 Global CaptureContextProvider skipped — no active tracked screen")
                Self.lastLoggedNilContext = true
            }
            return
        }

        // ✅ Allow only active tracked screens to set context
        Self.lastLoggedNilContext = false
        if let contentView = uiView.findActualContentView() {
            sdk.setCaptureContext(contentView)
            Logger.debug("✅ Capture context set: \(type(of: contentView))")
        } else {
            Logger.warning("⚠️ Could not find content view for capture context")
        }
    }

    private static var lastLoggedNilContext: Bool?

}

private class CaptureContextUIView: UIView {
    /// Find the actual visible content view
    func findActualContentView() -> UIView? {
        Logger.debug("🔍 Searching for actual content view (hybrid Tab + Nav deep mode)...")

        // ✅ Find key window
        guard let window = self.window ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: \.isKeyWindow) else {
            Logger.warning("⚠️ No window available")
            return nil
        }

        var bestCandidate: UIView?

        // MARK: - Recursive traversal to find best HostingView
        func traverse(_ view: UIView, depth: Int = 0) {
            guard depth < 25 else { return }
            let viewType = String(describing: type(of: view))

            // Skip irrelevant wrappers
            if viewType.contains("CaptureContext")
                || viewType.contains("UIViewControllerWrapper")
                || viewType.contains("TransitionView")
                || viewType.contains("Controller") {
                return
            }

            // ✅ Detect HostingView with visible tagged elements
            if viewType.contains("HostingView"),
               !viewType.contains("TabBar"),
               view.bounds.height > 100,
               view.containsTaggedElement() {
                Logger.debug("🎯 Leaf HostingView candidate: \(viewType) with tagged content ✅")
                bestCandidate = view
            }

            // ✅ Detect Tab-based HostingView (bottom tabs)
            if viewType.contains("HostingView"),
               view.superview?.description.contains("UIKitAdaptableTabView") == true {
                Logger.debug("🎯 Tab HostingView candidate: \(viewType)")
                bestCandidate = view
            }

            // Recurse
            for sub in view.subviews {
                traverse(sub, depth: depth + 1)
            }
        }

        traverse(window)

        // MARK: - Pick best candidate or fallback
        if let best = bestCandidate {
            if best.window != nil, best.containsTaggedElement() {
                Logger.info("🎯 Selected content view for capture: \(type(of: best)) frame:\(best.frame)")
                return best
            } else if let visibleSub = best.findVisibleHostingDescendant() {
                Logger.info("🎯 Using visible descendant HostingView for capture: \(type(of: visibleSub)) frame:\(visibleSub.frame)")
                return visibleSub
            } else {
                Logger.warning("⚠️ Best candidate not visible — falling back to window")
                return window
            }
        }

        // ✅ Deep fallback to the deepest visible HostingView
        if let fallback = window.deepestHostingView() {
            Logger.warning("⚠️ Using deepest HostingView as fallback: \(type(of: fallback)) frame:\(fallback.frame)")
            return fallback
        }

        Logger.error("❌ No suitable content view found, returning window")
        return window
    }


}

// MARK: - AppStorys Extension

extension AppStorys {
    private static var captureContext: CaptureContextProvider = CaptureContextProvider()
    
    func setCaptureContext(_ view: UIView) {
        Self.captureContext.currentView = view
    }
    
    func getCaptureView() throws -> UIView {
        if let contextView = Self.captureContext.currentView {
            let viewType = String(describing: type(of: contextView))
            Logger.debug("📸 Using context view: \(viewType)")
            return contextView
        }
        
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.keyWindow ?? scene.windows.first else {
            Logger.error("❌ No window available for capture")
            throw ScreenCaptureError.noActiveScreen
        }
        
        Logger.warning("⚠️ Using fallback window - add .captureContext() to your NavigationStack content!")
        return window
    }

    /// ✅ Add this public accessor
    var captureContextProvider: CaptureContextProvider {
        return Self.captureContext
    }
    
    func clearCaptureContext() {
        Self.captureContext.currentView = nil
        Logger.info("🧹 Capture context cleared — no active tracked view")
    }
    func isScreenCurrentlyVisible(_ name: String) -> Bool {
        return captureContextProvider.currentView != nil && currentScreen == name
    }


}


// MARK: - 🔍 Debug Helper: Dump Entire View Hierarchy
extension UIView {
    func dumpHierarchy(
        depth: Int = 0,
        prefix: String = ""
    ) {
        let indent = String(repeating: "  ", count: depth)
        let viewType = String(describing: type(of: self))
        let frameString = "(\(Int(frame.origin.x)), \(Int(frame.origin.y)), \(Int(frame.width)), \(Int(frame.height)))"
        let id = accessibilityIdentifier ?? "nil"
        Logger.debug("\(indent)• \(prefix)\(viewType)  id:\(id)  frame:\(frameString)  alpha:\(alpha)  window:\(window != nil ? "✅" : "❌")")

        // Avoid infinite recursion for huge trees
        guard depth < 25 else {
            Logger.debug("\(indent)  … (depth limit reached)")
            return
        }

        for (index, sub) in subviews.enumerated() {
            sub.dumpHierarchy(depth: depth + 1, prefix: "[\(index)] ")
        }
    }
}

// MARK: - UIView Utilities
private extension UIView {

    /// Finds visible HostingView deeper in hierarchy (attached to window and containing tags)
    func findVisibleHostingDescendant() -> UIView? {
        var candidate: UIView?

        func recurse(_ view: UIView) {
            let typeName = String(describing: type(of: view))
            if typeName.contains("HostingView"),
               view.window != nil,
               view.containsTaggedElement() {
                candidate = view
            }
            for sub in view.subviews {
                recurse(sub)
            }
        }

        recurse(self)
        return candidate
    }

    /// Checks recursively if any subview contains an AppStorys tag
    func containsTaggedElement() -> Bool {
        if let id = accessibilityIdentifier,
           id.starts(with: "APPSTORYS_") {
            return true
        }
        for sub in subviews where sub.containsTaggedElement() {
            return true
        }
        return false
    }

    /// Fallback: returns the deepest visible HostingView
    func deepestHostingView() -> UIView? {
        var result: UIView?
        func dive(_ view: UIView) {
            if String(describing: type(of: view)).contains("HostingView"),
               view.window != nil {
                result = view
            }
            for sub in view.subviews {
                dive(sub)
            }
        }
        dive(self)
        return result
    }
    
    
}
