//
//  AppStorys.swift
//  AppStorys_iOS
//
//  âœ… FIXED: Proper storyManager initialization and observation
//

import Foundation
import Combine
import UIKit
import SwiftUI

@MainActor
public class AppStorys: ObservableObject {
    // MARK: - Singleton
    public static let shared = AppStorys()
    
    // MARK: - Published Properties
    @Published public private(set) var isInitialized = false
    @Published public private(set) var campaigns: [CampaignModel] = []
    @Published public private(set) var trackedEvents: Set<String> = []
    @Published public private(set) var isScreenCaptureEnabled = false
    
    // MARK: - Active Campaign Publishers (Lightweight Overlays)
    @Published public var activeBannerCampaign: CampaignModel?
    @Published public var activeFloaterCampaign: CampaignModel?
    @Published public var activeCSATCampaign: CampaignModel?
    @Published public var activeSurveyCampaign: CampaignModel?
    @Published public var activeBottomSheetCampaign: CampaignModel?
    @Published public var activeModalCampaign: CampaignModel?
    @Published public var activeWidgetCampaign: CampaignModel?
    @Published public var activePIPCampaign: CampaignModel?
    
    // MARK: - Managers
    
    public let pipPlayerManager = PIPPlayerManager()
    public private(set) lazy var storyManager: StoryManager = {
        StoryManager { [weak self] eventType, campaignId, metadata in
            guard let self = self else { return }
            await self.trackEvents(
                eventType: eventType,
                campaignId: campaignId,
                metadata: metadata
            )
        }
    }()
    
    // MARK: - Story Presentation State
    
    /// Represents the state of story presentation
    public struct StoryPresentationState {
        let campaign: StoryCampaign
        let initialIndex: Int
    }
    
    @Published public private(set) var storyPresentationState: StoryPresentationState?
    
    // MARK: - Private Properties
    private var config: SDKConfiguration?
    private var authManager: AuthManager?
    private var networkClient: NetworkClient?
    private var webSocketClient: WebSocketClient?
    private var campaignManager: CampaignManager?
    private var pendingEventManager = PendingEventManager()
    var screenCaptureManager: ScreenCaptureManager?
    
    var currentUserID: String?
    private var userAttributes: [String: AnyCodable] = [:]
    var currentScreen: String?
    
    // Track dismissed campaigns per session
    private var dismissedCampaigns: Set<String> = []
    
    // System events that should not trigger campaign refresh
    private let systemEvents: Set<String> = [
        "viewed", "clicked", "dismissed", "expanded",
        "minimized", "completed", "closed", "submitted",
        // Add story-specific events
        "story_completed", "story_dismissed", "story_opened",
        "slide_viewed"
    ]
    
    // Event tracking debouncing
    private var eventTrackingTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Filtered Campaign Arrays (Read-Only)
    
    public var pipCampaigns: [CampaignModel] {
        safeFilteredCampaigns(type: "PIP")
    }
    
    public var bannerCampaigns: [CampaignModel] {
        safeFilteredCampaigns(type: "BAN")
    }
    
    public var floaterCampaigns: [CampaignModel] {
        safeFilteredCampaigns(type: "FLT")
    }
    
    public var csatCampaigns: [CampaignModel] {
        safeFilteredCampaigns(type: "CSAT")
    }
    
    public var surveyCampaigns: [CampaignModel] {
        safeFilteredCampaigns(type: "SUR")
    }
    
    public var widgetCampaigns: [CampaignModel] {
        safeFilteredCampaigns(type: "WID")
    }
    
    public var bottomSheetCampaigns: [CampaignModel] {
        safeFilteredCampaigns(type: "BTS")
    }
    
    public var modalCampaigns: [CampaignModel] {
        safeFilteredCampaigns(type: "MOD")
    }
    
    public var storyCampaigns: [StoryCampaign] {
        let currentCampaigns = campaigns
        let currentDismissed = dismissedCampaigns
        let currentTrackedEvents = trackedEvents
        
        return currentCampaigns.compactMap { campaign in
            guard campaign.campaignType == "STR",
                  case let .stories(storyDetails) = campaign.details else {
                return nil
            }
            
            if currentDismissed.contains(campaign.id) {
                return nil
            }
            
            if let triggerEvent = campaign.triggerEvent, !triggerEvent.isEmpty {
                guard currentTrackedEvents.contains(triggerEvent) else {
                    return nil
                }
            }
            
            return StoryCampaign(
                id: campaign.id,
                campaignType: campaign.campaignType,
                clientId: campaign.clientId,
                stories: storyDetails
            )
        }
    }
    
    // MARK: - Thread-Safe Filtering Helper
    
    private func safeFilteredCampaigns(type: String) -> [CampaignModel] {
        let currentCampaigns = campaigns
        let currentDismissed = dismissedCampaigns
        let currentTrackedEvents = trackedEvents
        
        return currentCampaigns.filter { campaign in
            guard campaign.campaignType == type else { return false }
            
            if currentDismissed.contains(campaign.id) {
                return false
            }
            
            if let triggerEvent = campaign.triggerEvent, !triggerEvent.isEmpty {
                return currentTrackedEvents.contains(triggerEvent)
            }
            
            return true
        }
    }
    
    // MARK: - Campaign Display Logic
    
    private func shouldShowCampaign(_ campaign: CampaignModel) -> Bool {
        if dismissedCampaigns.contains(campaign.id) {
            Logger.debug("ðŸš« Campaign \(campaign.id) is dismissed, skipping")
            return false
        }
        
        guard let triggerEvent = campaign.triggerEvent, !triggerEvent.isEmpty else {
            return true
        }
        
        return trackedEvents.contains(triggerEvent)
    }
    
    public func dismissCampaign(_ campaignId: String) {
        dismissedCampaigns.insert(campaignId)
        updateActiveCampaigns()
        Logger.info("ðŸš« Campaign \(campaignId) marked as dismissed for this session")
    }
    
    public func isCampaignDismissed(_ campaignId: String) -> Bool {
        dismissedCampaigns.contains(campaignId)
    }
    
    // MARK: - Trigger Event Logic
    
    public func addTrackedEvent(_ eventName: String) {
        trackedEvents.insert(eventName)
        Logger.info("âœ… Event tracked: \(eventName)")
        updateActiveCampaigns()
    }
    
    public func removeTrackedEvent(_ eventName: String) {
        trackedEvents.remove(eventName)
        updateActiveCampaigns()
    }
    
    public func clearTrackedEvents() {
        trackedEvents.removeAll()
        updateActiveCampaigns()
    }
    
    // MARK: - SDK Initialization
    
    public func appstorys(
        accountID: String,
        appID: String,
        userID: String,
        baseURL: String = "https://users.appstorys.com"
    ) async {
        Logger.info("ðŸš€ Initializing AppStorys SDK...")
        
        let configuration = SDKConfiguration(
            appID: appID,
            accountID: accountID,
            baseURL: baseURL
        )
        
        self.config = configuration
        self.currentUserID = userID
        
        self.authManager = AuthManager(config: configuration)
        self.networkClient = NetworkClient(authManager: authManager!)
        self.webSocketClient = WebSocketClient()
        self.campaignManager = CampaignManager(
            networkClient: networkClient!,
            webSocketClient: webSocketClient!,
            authManager: authManager!,
            baseURL: baseURL
        )
        
        do {
            try await authManager?.authenticate()
            await retryPendingEvents()
            self.isInitialized = true
            Logger.info("âœ… AppStorys SDK initialized successfully")
        } catch {
            Logger.error("âŒ Failed to initialize AppStorys SDK", error: error)
        }
    }
    
    public func setUserAttributes(_ attributes: [String: Any]) {
        self.userAttributes = attributes.mapValues { AnyCodable($0) }
        Logger.debug("User attributes updated: \(attributes.keys.joined(separator: ", "))")
    }
    
    // MARK: - Track Screen
    
    public func trackScreen(
        _ screenName: String,
        completion: @escaping ([CampaignModel]) -> Void = { _ in }
    ) {
        guard isInitialized, let userID = currentUserID else {
            Logger.error("SDK not initialized")
            completion([])
            return
        }
        
        if let previousScreen = currentScreen, previousScreen != screenName {
            Logger.debug("Screen changed from \(previousScreen) to \(screenName)")
            hideAllCampaigns()
            dismissedCampaigns.removeAll()
            Logger.debug("Cleared dismissed campaigns for new screen")
        }
        
        currentScreen = screenName
        let attributesCopy = self.userAttributes
        
        Task {
            do {
                let captureEnabled = try await campaignManager?.getScreenCaptureState(
                    screenName: screenName,
                    userID: userID,
                    attributes: attributesCopy
                ) ?? false
                
                await MainActor.run {
                    updateCaptureState(captureEnabled)
                }
                
                Logger.debug("âœ… Capture state updated in ~100-200ms")
                
            } catch {
                Logger.warning("âš ï¸ Failed to get capture state, using default (disabled)")
                await MainActor.run {
                    updateCaptureState(false)
                }
            }
            
            do {
                let campaigns = try await campaignManager?.trackScreen(
                    screenName: screenName,
                    userID: userID,
                    attributes: attributesCopy
                ) ?? []
                
                await MainActor.run {
                    self.campaigns = campaigns
                    self.updateActiveCampaigns()
                    
                    for campaign in self.storyCampaigns {
                        storyManager.prefetchCampaign(campaign)
                    }
                    
                    if campaigns.isEmpty {
                        Logger.info("âœ… Screen tracked: \(screenName) - No campaigns available")
                    } else {
                        Logger.info("âœ… Screen tracked: \(screenName) - \(campaigns.count) campaigns loaded")
                    }
                    completion(campaigns)
                }
                
            } catch {
                Logger.error("âŒ Failed to fetch campaigns", error: error)
                await MainActor.run {
                    self.campaigns = []
                    self.updateActiveCampaigns()
                    completion([])
                }
            }
        }
    }
    
    private func updateCaptureState(_ enabled: Bool) {
        guard self.isScreenCaptureEnabled != enabled else {
            Logger.debug(" Capture state unchanged: \(enabled)")
            return
        }
        
        Logger.info("Capture state changing: \(self.isScreenCaptureEnabled) â†’ \(enabled)")
        self.isScreenCaptureEnabled = enabled
        
        if enabled {
            if self.screenCaptureManager == nil {
                self.screenCaptureManager = ScreenCaptureManager(
                    authManager: self.authManager!,
                    baseURL: self.config?.baseURL ?? "https://users.appstorys.com"
                )
                Logger.info("Screen capture manager initialized")
            }
        } else {
            self.screenCaptureManager = nil
            Logger.info("Screen capture manager disabled")
        }
    }
    
    // MARK: - Screen Capture API
    
    public func captureScreen(from view: UIView) async throws {
        guard isInitialized else {
            throw AppStorysError.notInitialized
        }
        
        guard isScreenCaptureEnabled else {
            Logger.warning("âš ï¸ Screen capture is disabled by server")
            throw ScreenCaptureError.featureDisabled
        }
        
        guard let manager = screenCaptureManager else {
            Logger.error("âŒ Screen capture manager not initialized")
            throw ScreenCaptureError.managerNotInitialized
        }
        
        guard let userId = currentUserID else {
            throw AppStorysError.notInitialized
        }
        
        guard let screenName = currentScreen else {
            Logger.warning("âš ï¸ No active screen to capture")
            throw ScreenCaptureError.noActiveScreen
        }
        
        try await manager.captureAndUpload(
            screenName: screenName,
            userId: userId,
            rootView: view
        )
    }
    
    // MARK: - Track Event
    
    public func trackEvents(
        eventType: String,
        campaignId: String,
        metadata: [String: Any]? = nil
    ) async {
        guard isInitialized, let userID = currentUserID else {
            Logger.warning("âš ï¸ SDK not initialized, queuing event")
            await pendingEventManager.save(
                campaignId: campaignId,
                event: eventType,
                metadata: metadata?.mapValues { AnyCodable($0) }
            )
            return
        }
        
        let isSystemEvent = systemEvents.contains(eventType)
        
        if !isSystemEvent {
            addTrackedEvent(eventType)
            Logger.debug("Added custom event '\(eventType)' to tracked events")
        } else {
            Logger.debug("Tracking system event: \(eventType)")
        }
        
        let metadataCopy: [String: AnyCodable]? = metadata?.mapValues { AnyCodable($0) }
        
        let taskKey = "\(campaignId)-\(eventType)"
        eventTrackingTasks[taskKey]?.cancel()
        
        eventTrackingTasks[taskKey] = Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            guard !Task.isCancelled else {
                Logger.debug("Event tracking cancelled: \(eventType)")
                return
            }
            
            do {
                try await campaignManager?.trackEvent(
                    campaignID: campaignId,
                    userID: userID,
                    event: eventType,
                    metadata: metadataCopy
                )
                
                Logger.debug("Event tracked: \(eventType) for campaign: \(campaignId)")
                
                if !isSystemEvent {
                    Logger.debug("Refreshing campaigns due to custom event: \(eventType)")
                    await refreshCampaigns()
                }
            } catch {
                Logger.error("Failed to track event", error: error)
                
                await pendingEventManager.save(
                    campaignId: campaignId,
                    event: eventType,
                    metadata: metadataCopy
                )
            }
            
            await MainActor.run {
                eventTrackingTasks.removeValue(forKey: taskKey)
            }
        }
    }
    
    // MARK: - Active Campaign Management
    
    private func updateActiveCampaigns() {
        activeBannerCampaign = bannerCampaigns.first
        activeFloaterCampaign = floaterCampaigns.first
        activeCSATCampaign = csatCampaigns.first
        activeSurveyCampaign = surveyCampaigns.first
        activeBottomSheetCampaign = bottomSheetCampaigns.first
        activeModalCampaign = modalCampaigns.first
        activeWidgetCampaign = widgetCampaigns.first
        activePIPCampaign = pipCampaigns.first
        
        Logger.debug("Active campaigns updated")
    }
    
    // MARK: - Public Campaign Control Methods
    
    public func hideAllCampaigns() {
        activeBannerCampaign = nil
        activeFloaterCampaign = nil
        activeCSATCampaign = nil
        activeSurveyCampaign = nil
        activeBottomSheetCampaign = nil
        activeModalCampaign = nil
        activeWidgetCampaign = nil
        activePIPCampaign = nil
        
        Logger.debug("All campaigns hidden")
    }
    
    public func hidePIPCampaign() {
        activePIPCampaign = nil
        Logger.debug("PiP campaign hidden")
    }
    
    // MARK: - Story Presentation
    
    /// Present a story campaign at a specific group index
    public func presentStory(campaign: StoryCampaign, initialGroupIndex: Int = 0) {
        storyPresentationState = StoryPresentationState(
            campaign: campaign,
            initialIndex: initialGroupIndex
        )
        storyManager.openStory(campaign: campaign, initialGroupIndex: initialGroupIndex)
        Logger.info("📖 Presenting story campaign: \(campaign.id)")
    }
    
    /// Dismiss the active story
    public func dismissStory() {
        storyPresentationState = nil
        storyManager.closeStory()
        Logger.info("📕 Dismissed story")
    }
    
    // MARK: - Offline Support
    
    private func retryPendingEvents() async {
        guard isInitialized, let userID = currentUserID else { return }
        
        let pendingEvents = await pendingEventManager.getAll()
        guard !pendingEvents.isEmpty else { return }
        
        Logger.info("Retrying \(pendingEvents.count) pending events...")
        
        for event in pendingEvents {
            if let campaignId = event.campaignId {
                await trackEvents(
                    eventType: event.event,
                    campaignId: campaignId,
                    metadata: event.metadata?.mapValues { $0.value }
                )
            }
        }
        
        await pendingEventManager.clear()
        Logger.info("Pending events retry completed")
    }
    
    private func refreshCampaigns() async {
        guard let currentScreen = currentScreen else { return }
        
        trackScreen(currentScreen) { _ in
            Logger.debug("Campaigns refreshed for screen: \(currentScreen)")
        }
    }
    
    // MARK: - Cleanup
    
    public func cleanup() {
        hideAllCampaigns()
        campaigns.removeAll()
        trackedEvents.removeAll()
        dismissedCampaigns.removeAll()
        currentScreen = nil
        isScreenCaptureEnabled = false
        screenCaptureManager = nil
        
        eventTrackingTasks.values.forEach { $0.cancel() }
        eventTrackingTasks.removeAll()
        
        Logger.info("AppStorys SDK cleaned up")
    }
    
    public func shutdownAsync() async {
        cleanup()
        await webSocketClient?.disconnect()
        await pendingEventManager.clear()
        Logger.info("AppStorys SDK shutdown complete")
    }
    
    public func reset() {
        cleanup()
        campaigns.removeAll()
        trackedEvents.removeAll()
        dismissedCampaigns.removeAll()
        currentScreen = nil
        userAttributes.removeAll()
        isScreenCaptureEnabled = false
        screenCaptureManager = nil
        
        Logger.info("AppStorys SDK reset to initial state")
    }
}

// MARK: - Debug Helpers
extension AppStorys {
    public var debugInfo: String {
        """
        AppStorys SDK Debug Info
        
        Initialized: \(isInitialized)
        User ID: \(currentUserID ?? "nil")
        Current Screen: \(currentScreen ?? "nil")
        Total Campaigns: \(campaigns.count)
        Tracked Events: \(trackedEvents.count)
        Dismissed Campaigns: \(dismissedCampaigns.count)
        Screen Capture: \(isScreenCaptureEnabled ? "âœ… ENABLED" : "âŒ disabled")
        
        Active Campaigns:
        - Banner: \(activeBannerCampaign != nil ? "âœ…" : "âŒ")
        - Floater: \(activeFloaterCampaign != nil ? "âœ…" : "âŒ")
        - PIP: \(activePIPCampaign != nil ? "âœ…" : "âŒ")
        - CSAT: \(activeCSATCampaign != nil ? "âœ…" : "âŒ")
        - Survey: \(activeSurveyCampaign != nil ? "âœ…" : "âŒ")
        - Bottom Sheet: \(activeBottomSheetCampaign != nil ? "âœ…" : "âŒ")
        - Modal: \(activeModalCampaign != nil ? "âœ…" : "âŒ")
        - Widget: \(activeWidgetCampaign != nil ? "âœ…" : "âŒ")
        
        Tracked Events: \(Array(trackedEvents).joined(separator: ", "))
        Dismissed IDs: \(Array(dismissedCampaigns).joined(separator: ", "))
        """
    }
    
    public func printDebugInfo() {
        print(debugInfo)
    }
}
