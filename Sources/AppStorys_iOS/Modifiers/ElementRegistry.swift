//
//  ElementRegistry.swift
//  AppStorys_iOS
//
//  ✅ ENHANCED: Now detects UITabBar items automatically
//

import UIKit
import SwiftUI

/// Centralized registry for tagged UI elements
/// - Eliminates duplicate view hierarchy traversals
/// - Single source of truth for element positions
/// - Shared by screen capture and tooltips
/// - ✅ NEW: Auto-detects UITabBar items
@MainActor
public class ElementRegistry: ObservableObject {
    
    // MARK: - Published State
    
    /// Element positions in screen coordinates
    @Published public private(set) var elementFrames: [String: CGRect] = [:]
    
    /// Last scan timestamp for cache invalidation
    @Published public private(set) var lastScanTime: Date?
    
    // MARK: - Configuration
    
    private let capturePrefix = "APPSTORYS_"
    private let cacheValidityDuration: TimeInterval = 2.0 // 2 seconds
    
    // MARK: - Weak References
    
    private weak var currentRootView: UIView?
    
    // MARK: - Public API
    
    /// Discover all tagged elements in view hierarchy
    /// - Parameter rootView: Root view to scan from
    /// - Parameter forceRefresh: Bypass cache and force new scan
    /// - Returns: Dictionary of element IDs to frames
    public func discoverElements(
        in rootView: UIView,
        forceRefresh: Bool = false
    ) -> [String: CGRect] {
        // ✅ Cache validation
        if !forceRefresh,
           let lastScan = lastScanTime,
           Date().timeIntervalSince(lastScan) < cacheValidityDuration,
           currentRootView === rootView {
            Logger.debug("✅ Using cached elements (\(elementFrames.count) elements)")
            return elementFrames
        }
        
        // ✅ Scan hierarchy
        Logger.debug("🔍 Scanning view hierarchy for tagged elements...")
        Logger.debug("   Starting from: \(type(of: rootView))")
        
        currentRootView = rootView
        var discovered: [String: CGRect] = [:]
        let pixelRatio = UIScreen.main.scale
        
        // ✅ SCAN PROVIDED VIEW FIRST
        scanView(rootView, into: &discovered, pixelRatio: pixelRatio)
        
        // ✅ NEW: Auto-detect UITabBar items
        detectTabBarItems(rootView: rootView, into: &discovered, pixelRatio: pixelRatio)
        
        // ✅ FALLBACK: Scan all windows if nothing found
        if discovered.isEmpty {
            Logger.warning("⚠️ No elements found in rootView, scanning all windows...")
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                Logger.error("❌ No window scene available")
                elementFrames = discovered
                lastScanTime = Date()
                return discovered
            }
            
            for window in windowScene.windows {
                let windowType = String(describing: type(of: window))
                Logger.debug("   🪟 Scanning window: \(windowType)")
                scanView(window, into: &discovered, pixelRatio: pixelRatio)
                
                // ✅ Also check for TabBar in this window
                detectTabBarItems(rootView: window, into: &discovered, pixelRatio: pixelRatio)
                
                if !discovered.isEmpty {
                    Logger.info("   ✅ Found \(discovered.count) elements in \(windowType)")
                    break
                }
            }
        }
        
        elementFrames = discovered
        lastScanTime = Date()
        
        Logger.info("✅ Discovered \(discovered.count) elements total")
        return discovered
    }
    
    /// Get frame for specific element
    /// - Parameter id: Element identifier (without APPSTORYS_ prefix)
    /// - Returns: Frame in screen coordinates, or nil if not found
    public func getFrame(for id: String) -> CGRect? {
        return elementFrames[id]
    }
    
    /// Check if element exists
    public func hasElement(_ id: String) -> Bool {
        return elementFrames[id] != nil
    }
    
    /// Invalidate cache (call on layout changes, rotation, etc)
    public func invalidateCache() {
        Logger.debug("🔄 Cache invalidated")
        lastScanTime = nil
    }
    
    /// Clear all discovered elements
    public func clear() {
        elementFrames.removeAll()
        lastScanTime = nil
        currentRootView = nil
        Logger.debug("🧹 Registry cleared")
    }
    
    // MARK: - Element Extraction (Used by Both Features)
    
    /// Extract elements for screen capture upload
    /// Returns layout data in backend-compatible format
    public func extractLayoutData() -> [LayoutElement] {
        let pixelRatio = UIScreen.main.scale
        
        return elementFrames.map { id, frame in
            LayoutElement(
                id: id,
                frame: LayoutFrame(
                    x: Int(frame.origin.x * pixelRatio),
                    y: Int(frame.origin.y * pixelRatio),
                    width: Int(frame.size.width * pixelRatio),
                    height: Int(frame.size.height * pixelRatio)
                ),
                type: "UIView",
                depth: 0
            )
        }
    }
    
    // MARK: - ✅ NEW: UITabBar Detection
    
    /// Automatically detect and tag UITabBar items
    private func detectTabBarItems(
        rootView: UIView,
        into discovered: inout [String: CGRect],
        pixelRatio: CGFloat
    ) {
        // Find UITabBar in hierarchy
        guard let tabBar = findTabBar(in: rootView) else {
            return
        }
        
        Logger.debug("📱 Found UITabBar, detecting items...")
        
        // Get tab bar's frame in window coordinates
        guard let window = tabBar.window else {
            Logger.warning("⚠️ TabBar not in window")
            return
        }
        
        let tabBarFrame = tabBar.convert(tabBar.bounds, to: window)
        
        // Tag the entire tab bar
        discovered["tab_bar"] = tabBarFrame
        Logger.info("   📍 FOUND [auto] tab_bar: \(tabBarFrame)")
        
        // ✅ Detect individual tab items
        // UITabBar has subviews that are the actual buttons
        for (index, subview) in tabBar.subviews.enumerated() {
            let viewType = String(describing: type(of: subview))
            
            // UITabBarButton is private, so check by type name
            if viewType.contains("Button") {
                let itemFrame = subview.convert(subview.bounds, to: window)
                
                // Only add if frame is valid
                if itemFrame.width > 0 && itemFrame.height > 0 {
                    let itemId = "tab_item_\(index)"
                    discovered[itemId] = itemFrame
                    Logger.info("   📍 FOUND [auto] \(itemId): \(itemFrame)")
                    
                    // ✅ Try to get item title for better identification
                    if let button = subview as? UIControl {
                        // Try to find label within button
                        for innerView in button.subviews {
                            if let label = innerView as? UILabel,
                               let text = label.text,
                               !text.isEmpty {
                                let labelId = "tab_\(text.lowercased().replacingOccurrences(of: " ", with: "_"))"
                                discovered[labelId] = itemFrame
                                Logger.info("   📍 FOUND [auto] \(labelId): \(itemFrame)")
                                break
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Find UITabBar in view hierarchy
    private func findTabBar(in view: UIView) -> UITabBar? {
        // Check if current view is a tab bar
        if let tabBar = view as? UITabBar {
            return tabBar
        }
        
        // Recursively search subviews
        for subview in view.subviews {
            if let tabBar = findTabBar(in: subview) {
                return tabBar
            }
        }
        
        return nil
    }
    
    // MARK: - Private Scanning Logic
    
    /// Recursive view hierarchy scan
    private func scanView(
        _ view: UIView,
        into discovered: inout [String: CGRect],
        pixelRatio: CGFloat,
        depth: Int = 0
    ) {
        // Log view types (first 5 levels)
        if depth <= 5 {
            let viewType = String(describing: type(of: view))
            let identifier = view.accessibilityIdentifier ?? "nil"
            Logger.debug("      [\(depth)] \(viewType) - ID: \(identifier)")
        }
        
        // ✅ Check for tag (but don't return early if not visible)
        var shouldProcessTag = !view.isHidden && view.alpha > 0
        
        if shouldProcessTag,
           let identifier = view.accessibilityIdentifier,
           identifier.hasPrefix(capturePrefix) {
            
            let cleanId = String(identifier.dropFirst(capturePrefix.count))
            
            // Skip duplicates (keep first found)
            if discovered[cleanId] == nil {
                // Get frame in screen coordinates
                if let window = view.window {
                    let frameInWindow = view.convert(view.bounds, to: window)
                    
                    // Only store if frame is valid
                    if frameInWindow.width > 0 && frameInWindow.height > 0 {
                        discovered[cleanId] = frameInWindow
                        Logger.info("      📍 FOUND [\(depth)] \(cleanId): \(frameInWindow)")
                    } else {
                        Logger.warning("      ⚠️ Skipping '\(cleanId)' - zero size frame")
                    }
                } else {
                    Logger.warning("      ⚠️ View '\(cleanId)' not in window, skipping")
                }
            } else {
                Logger.debug("      🔁 Duplicate '\(cleanId)' skipped")
            }
        }
        
        // ✅ CRITICAL: ALWAYS recurse into children
        for subview in view.subviews {
            scanView(subview, into: &discovered, pixelRatio: pixelRatio, depth: depth + 1)
        }
    }
    
    // MARK: - Async Element Waiting
    
    /// Wait for multiple elements to appear in the view hierarchy
    /// - Parameters:
    ///   - ids: Element IDs to wait for
    ///   - rootView: Root view to scan
    ///   - timeout: Overall timeout for waiting
    ///   - requireAll: If false, returns as soon as ANY element is found (graceful degradation)
    /// - Returns: Dictionary of found element IDs to frames
    public func waitForElements(
        _ ids: [String],
        in rootView: UIView,
        timeout: TimeInterval = 2.0,
        requireAll: Bool = false
    ) async -> [String: CGRect] {
        let startTime = Date()
        
        // ✅ STEP 1: Quick check for already-cached elements
        var results: [String: CGRect] = [:]
        var pendingIds = ids
        
        for id in ids {
            if let frame = elementFrames[id], frame.width > 0, frame.height > 0 {
                results[id] = frame
                pendingIds.removeAll { $0 == id }
            }
        }
        
        // Early exit if all found in cache
        if pendingIds.isEmpty {
            let elapsed = Date().timeIntervalSince(startTime) * 1000
            Logger.debug("✅ All \(ids.count) elements found in cache (\(String(format: "%.0f", elapsed))ms)")
            return results
        }
        
        Logger.info("⏳ Waiting for \(pendingIds.count) elements (timeout: \(timeout)s)...")
        
        let shortTimeout = min(timeout, 0.5)
        
        if !requireAll {
            await withTaskGroup(of: (String, CGRect?).self) { group in
                for id in pendingIds {
                    group.addTask {
                        let frame = await self.waitForElement(
                            id,
                            in: rootView,
                            timeout: shortTimeout,
                            pollInterval: 0.05
                        )
                        return (id, frame)
                    }
                }
                
                var foundAny = false
                for await (id, frame) in group {
                    if let frame = frame {
                        results[id] = frame
                        if !foundAny {
                            foundAny = true
                            let elapsed = Date().timeIntervalSince(startTime) * 1000
                            Logger.info("⚡ First element '\(id)' found after \(String(format: "%.0f", elapsed))ms")
                        }
                    }
                }
            }
            
        } else {
            await withTaskGroup(of: (String, CGRect?).self) { group in
                for id in pendingIds {
                    group.addTask {
                        let frame = await self.waitForElement(
                            id,
                            in: rootView,
                            timeout: timeout,
                            pollInterval: 0.05
                        )
                        return (id, frame)
                    }
                }
                
                for await (id, frame) in group {
                    if let frame = frame {
                        results[id] = frame
                    }
                }
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime) * 1000
        let missing = ids.filter { results[$0] == nil }
        
        if missing.isEmpty {
            Logger.info("✅ All \(ids.count) elements found (\(String(format: "%.0f", elapsed))ms)")
        } else if requireAll {
            Logger.warning("⚠️ Found \(results.count)/\(ids.count) elements (\(String(format: "%.0f", elapsed))ms), missing: \(missing)")
        } else {
            Logger.info("✅ Found \(results.count)/\(ids.count) available elements (\(String(format: "%.0f", elapsed))ms)")
            if !missing.isEmpty {
                Logger.debug("   Missing (timed out after \(String(format: "%.1f", shortTimeout))s each): \(missing)")
            }
        }
        
        return results
    }
    
    /// Wait for a single element to appear in the view hierarchy
    public func waitForElement(
        _ id: String,
        in rootView: UIView,
        timeout: TimeInterval = 2.0,
        pollInterval: TimeInterval = 0.05,
        maxScans: Int? = nil
    ) async -> CGRect? {
        let deadline = Date().addingTimeInterval(timeout)
        let startTime = Date()
        var scanCount = 0
        var currentPollInterval = pollInterval
        
        let effectiveMaxScans = maxScans ?? Int(timeout / pollInterval) + 5
        
        while Date() < deadline && scanCount < effectiveMaxScans {
            if let frame = elementFrames[id], frame.width > 0, frame.height > 0 {
                let elapsed = Date().timeIntervalSince(startTime) * 1000
                Logger.debug("✅ Element '\(id)' found after \(String(format: "%.0f", elapsed))ms (\(scanCount) scans)")
                return frame
            }
            
            let _ = discoverElements(in: rootView, forceRefresh: true)
            scanCount += 1
            
            if let frame = elementFrames[id], frame.width > 0, frame.height > 0 {
                let elapsed = Date().timeIntervalSince(startTime) * 1000
                Logger.debug("✅ Element '\(id)' appeared after \(String(format: "%.0f", elapsed))ms (\(scanCount) scans)")
                return frame
            }
            
            if scanCount <= 3 {
                currentPollInterval = pollInterval
            } else if scanCount <= 10 {
                currentPollInterval = pollInterval * 2
            } else {
                currentPollInterval = min(pollInterval * 4, 0.2)
            }
            
            try? await Task.sleep(nanoseconds: UInt64(currentPollInterval * 1_000_000_000))
        }
        
        let elapsed = Date().timeIntervalSince(startTime) * 1000
        if scanCount >= effectiveMaxScans {
            Logger.warning("⏹️ Element '\(id)' not found after \(scanCount) scans (\(String(format: "%.0f", elapsed))ms) - scan limit reached")
        } else {
            Logger.warning("⏰ Element '\(id)' not found after \(String(format: "%.1f", timeout))s timeout (\(scanCount) scans)")
        }
        return nil
    }
}

// MARK: - Layout Change Observer

extension ElementRegistry {
    
    /// Observe layout changes and auto-invalidate cache
    public func observeLayoutChanges(in view: UIView) {
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateCache()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateCache()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateCache()
        }
    }
    
    /// Stop observing (cleanup)
    nonisolated public func stopObserving() {
        NotificationCenter.default.removeObserver(self)
    }
}
