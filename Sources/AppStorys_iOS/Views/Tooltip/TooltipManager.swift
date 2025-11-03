//
//  TooltipManager.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 01/11/25.
//
//  Manages tooltip presentation state and step progression
//  ✅ Uses ElementRegistry - no duplicate view traversal
//  ✅ Tracks screen context to prevent wrong-screen display
//  ✅ CRITICAL: Caches element frames to prevent registry clearing issues
//

import SwiftUI
import UIKit

@MainActor
public class TooltipManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published public var currentStep: Int = 0
    @Published public var isPresenting: Bool = false
    
    // MARK: - Dependencies
    
    private let elementRegistry: ElementRegistry
    private weak var sdk: AppStorys?
    
    // MARK: - State
    
    private var currentCampaign: CampaignModel?
    private var tooltipDetails: TooltipDetails?
    
    // ✅ NEW: Track which screen tooltip is for
    private var presentedOnScreen: String?
    
    // ✅ CRITICAL: Cache element frames at presentation time
    private var cachedFrames: [String: CGRect] = [:]
    
    // MARK: - Initialization
    
    public init(elementRegistry: ElementRegistry) {
        self.elementRegistry = elementRegistry
    }
    
    /// Set SDK reference for event tracking
    func setSDK(_ sdk: AppStorys) {
        self.sdk = sdk
    }
    
    // MARK: - Presentation
    
    /// Present tooltip campaign
    /// - Parameters:
    ///   - campaign: Tooltip campaign to present
    ///   - rootView: Root view to scan for elements
    /// - Returns: true if presented successfully, false if missing targets
    @discardableResult
    public func present(campaign: CampaignModel, rootView: UIView) -> PresentationResult {
        guard case .tooltip(let details) = campaign.details else {
            return .failure(.invalidCampaign)
        }
        
        // Check if already presenting
        guard !isPresenting else {
            Logger.warning("⚠️ Tooltip already presenting")
            return .failure(.alreadyPresenting)
        }
        
        // Discover elements
        let elements = elementRegistry.discoverElements(in: rootView, forceRefresh: true)
        
        // ✅ Separate available vs missing steps
        var availableSteps: [(step: TooltipStep, frame: CGRect)] = []
        var missingSteps: [String] = []
        
        for tooltip in details.tooltips {
            if let frame = elements[tooltip.target],
               frame.width > 0,
               frame.height > 0 {
                availableSteps.append((tooltip, frame))
                cachedFrames[tooltip.target] = frame
            } else {
                missingSteps.append(tooltip.target)
            }
        }
        
        // ✅ Present if ANY steps available
        guard !availableSteps.isEmpty else {
            Logger.error("❌ No tooltip targets found: \(missingSteps)")
            return .failure(.noTargetsFound(missingSteps))
        }
        
        // ⚠️ Warn about missing steps but continue
        if !missingSteps.isEmpty {
            Logger.warning("⚠️ Skipping \(missingSteps.count) unavailable steps: \(missingSteps)")
        }
        
        // Store only available steps
        self.currentCampaign = campaign
        self.tooltipDetails = TooltipDetails(
            from: details,  // ✅ Original details with all metadata
            filteredTooltips: availableSteps.map(\.step)  // ✅ Only available steps
        )
        self.currentStep = 0
        self.isPresenting = true
        self.presentedOnScreen = campaign.screen
        
        Logger.info("✅ Presenting tooltip with \(availableSteps.count)/\(details.tooltips.count) steps")
        
        trackEvent(type: "viewed", metadata: [
            "step": 1,
            "available_steps": availableSteps.count,
            "missing_steps": missingSteps.count,
            "skipped_targets": missingSteps.joined(separator: ",")
        ])
        
        return .success(availableSteps.count)
    }

    public func presentWithWaiting(
        campaign: CampaignModel,
        rootView: UIView,
        elementTimeout: TimeInterval = 1.5
    ) async -> PresentationResult {
        guard case .tooltip(let details) = campaign.details else {
            return .failure(.invalidCampaign)
        }
        
        guard !isPresenting else {
            Logger.warning("⚠️ Tooltip already presenting")
            return .failure(.alreadyPresenting)
        }
        
        Logger.info("⏳ Waiting for tooltip elements (timeout: \(elementTimeout)s)...")
        
        // ✅ OPTIMIZATION: Use requireAll=false for graceful degradation
        // This will return as soon as ANY element is found
        let targetIds = details.tooltips.map { $0.target }
        let foundElements = await elementRegistry.waitForElements(
            targetIds,
            in: rootView,
            timeout: elementTimeout,
            requireAll: false  // ✅ NEW: Exit early on partial success
        )
        
        // Separate available vs missing
        var availableSteps: [(step: TooltipStep, frame: CGRect)] = []
        var missingSteps: [String] = []
        
        for tooltip in details.tooltips {
            if let frame = foundElements[tooltip.target] {
                availableSteps.append((tooltip, frame))
                cachedFrames[tooltip.target] = frame
            } else {
                missingSteps.append(tooltip.target)
            }
        }
        
        // Present if ANY steps available
        guard !availableSteps.isEmpty else {
            Logger.error("❌ No tooltip targets found after waiting: \(missingSteps)")
            return .failure(.noTargetsFound(missingSteps))
        }
        
        // Warn about missing steps
        if !missingSteps.isEmpty {
            Logger.warning("⚠️ Skipping \(missingSteps.count) unavailable steps: \(missingSteps)")
        }
        
        // Store only available steps
        self.currentCampaign = campaign
        self.tooltipDetails = TooltipDetails(
            from: details,
            filteredTooltips: availableSteps.map(\.step)
        )
        self.currentStep = 0
        self.isPresenting = true
        self.presentedOnScreen = campaign.screen
        
        Logger.info("✅ Presenting tooltip with \(availableSteps.count)/\(details.tooltips.count) steps")
        
        trackEvent(type: "viewed", metadata: [
            "step": 1,
            "available_steps": availableSteps.count,
            "missing_steps": missingSteps.count,
            "wait_duration": elementTimeout
        ])
        
        return .success(availableSteps.count)
    }
    // Return type for better error handling
    public enum PresentationResult {
        case success(Int)  // number of steps presented
        case failure(PresentationError)
        
        public enum PresentationError {
            case invalidCampaign
            case noTargetsFound([String])  // List of missing targets
            case alreadyPresenting
        }
    }
    
    public func validateScreen(_ currentScreen: String) -> Bool {
        guard let presentedScreen = presentedOnScreen else {
            return true  // No screen tracking, allow display
        }
        
        let matches = presentedScreen.lowercased() == currentScreen.lowercased()
        
        if !matches {
            Logger.warning("⚠️ Tooltip screen mismatch: expected '\(presentedScreen)' but on '\(currentScreen)'")
            dismiss()  // Auto-dismiss on screen change
        }
        
        return matches
    }
    
    // MARK: - Navigation
    
    /// Move to next tooltip step
    public func nextStep() {
        guard let details = tooltipDetails else { return }
        
        if currentStep < details.tooltips.count - 1 {
            currentStep += 1
            Logger.debug("➡️ Moving to tooltip step \(currentStep + 1)")
            
            trackEvent(
                type: "viewed",
                metadata: ["step": currentStep + 1]
            )
        } else {
            // Last step, complete and dismiss
            trackEvent(
                type: "completed",
                metadata: ["total_steps": details.tooltips.count]
            )
            dismiss()
        }
    }
    
    /// Move to previous tooltip step
    public func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
            Logger.debug("⬅️ Moving to tooltip step \(currentStep + 1)")
            
            trackEvent(
                type: "viewed",
                metadata: ["step": currentStep + 1]
            )
        }
    }
    
    /// Jump to specific step
    public func goToStep(_ step: Int) {
        guard let details = tooltipDetails,
              step >= 0,
              step < details.tooltips.count else {
            return
        }
        
        currentStep = step
        Logger.debug("🎯 Jumped to tooltip step \(step + 1)")
        
        trackEvent(
            type: "viewed",
            metadata: ["step": step + 1]
        )
    }
    
    /// Dismiss tooltip
    public func dismiss() {
        guard isPresenting else { return }
        
        isPresenting = false
        
        trackEvent(
            type: "dismissed",
            metadata: [
                "step": currentStep + 1,
                "reason": "user_action"
            ]
        )
        
        // Reset state
        currentStep = 0
        currentCampaign = nil
        tooltipDetails = nil
        presentedOnScreen = nil
        cachedFrames.removeAll()  // ✅ Clear cached frames
        
        Logger.info("📌 Dismissed tooltip")
    }
    
    // MARK: - Screen Validation
    
    /// ✅ NEW: Check if tooltip should still be shown on current screen
    /// - Parameter screenName: Name of the current screen
    /// - Returns: true if tooltip should display, false if screen mismatch
    public func shouldDisplay(forScreen screenName: String) -> Bool {
        guard isPresenting else { return false }
        
        // If no screen was stored, allow display (backwards compatibility)
        guard let presentedScreen = presentedOnScreen else {
            return true
        }
        
        // Case-insensitive comparison
        let matches = presentedScreen.lowercased() == screenName.lowercased()
        
        if !matches {
            Logger.warning("⚠️ Tooltip screen mismatch: expected '\(presentedScreen)' but on '\(screenName)'")
            // Auto-dismiss tooltip when screen changes
            dismiss()
        }
        
        return matches
    }
    
    /// ✅ NEW: Manually validate current screen context
    /// Useful for checking before rendering
    public var currentScreen: String? {
        return presentedOnScreen
    }
    
    // MARK: - Accessors
    
    /// Get current tooltip data for rendering
    /// ✅ CRITICAL: Now uses cached frames instead of registry
    public func getCurrentTooltip() -> (campaign: CampaignModel, step: TooltipStep, frame: CGRect)? {
        guard let campaign = currentCampaign,
              let details = tooltipDetails,
              currentStep < details.tooltips.count else {
            Logger.warning("⚠️ No tooltip data available")
            return nil
        }
        
        let tooltip = details.tooltips[currentStep]
        
        // ✅ Get frame from CACHE, not registry
        guard let frame = cachedFrames[tooltip.target] else {
            Logger.error("❌ Cached frame not found for '\(tooltip.target)'")
            Logger.error("   Available cached frames: \(cachedFrames.keys.joined(separator: ", "))")
            return nil
        }
        
        // Validate frame
        guard frame.width > 0 && frame.height > 0 else {
            Logger.error("❌ Invalid cached frame for '\(tooltip.target)': \(frame)")
            return nil
        }
        
        Logger.debug("✅ Using cached frame for '\(tooltip.target)': \(frame)")
        return (campaign, tooltip, frame)
    }
    
    /// Check if specific target element exists
    public func hasTarget(_ targetId: String) -> Bool {
        return elementRegistry.hasElement(targetId)
    }
    
    /// Get total step count
    public var totalSteps: Int {
        return tooltipDetails?.tooltips.count ?? 0
    }
    
    /// Check if on first step
    public var isFirstStep: Bool {
        return currentStep == 0
    }
    
    /// Check if on last step
    public var isLastStep: Bool {
        return currentStep == totalSteps - 1
    }
    
    // MARK: - Debug Helpers
    
    /// Debug: Print current state
    public func debugState() {
        Logger.debug("=== TooltipManager State ===")
        Logger.debug("isPresenting: \(isPresenting)")
        Logger.debug("currentStep: \(currentStep)/\(totalSteps)")
        Logger.debug("presentedOnScreen: \(presentedOnScreen ?? "nil")")
        Logger.debug("cachedFrames: \(cachedFrames.count)")
        for (id, frame) in cachedFrames {
            Logger.debug("  \(id): \(frame)")
        }
        Logger.debug("========================")
    }
    
    // MARK: - Event Tracking
    
    /// ✅ FIXED: Pass raw values, not AnyCodable-wrapped
    private func trackEvent(type: String, metadata: [String: Any]? = nil) {
        guard let campaign = currentCampaign else { return }
        
        Task {
            await sdk?.trackEvents(
                eventType: type,
                campaignId: campaign.id,
                metadata: metadata  // ← Already correct type
            )
        }
    }
}

// MARK: - Tooltip Step Extensions

extension TooltipStep {
    /// Convenience computed properties for rendering
    
    var highlightPadding: CGFloat {
        CGFloat(Double(styling.highlightPadding) ?? 6)
    }
    
    var highlightRadius: CGFloat {
        CGFloat(Double(styling.highlightRadius) ?? 20)
    }
    
    var tooltipWidth: CGFloat {
        CGFloat(Double(styling.tooltipDimensions.width) ?? 200)
    }
    
    var tooltipHeight: CGFloat {
        CGFloat(Double(styling.tooltipDimensions.height) ?? 200)
    }
    
    var tooltipCornerRadius: CGFloat {
        CGFloat(Double(styling.tooltipDimensions.cornerRadius) ?? 20)
    }
    
    var arrowWidth: CGFloat {
        CGFloat(Double(styling.tooltipArrow.arrowWidth) ?? 10)
    }
    
    var arrowHeight: CGFloat {
        CGFloat(Double(styling.tooltipArrow.arrowHeight) ?? 10)
    }
    
    var backgroundColor: Color {
        Color(hex: styling.backgroundColor) ?? .clear
    }
}
