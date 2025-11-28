//
//  AppStorys.swift - Context-Aware Navigation & Smart Caching
//
//  âœ… NAVIGATION TRACKING: Differentiates user flows for cache decisions
//  âœ… CAMPAIGN COMPARISON: Prevents unnecessary UI updates
//  âœ… METADATA SEPARATION: Fast-expiring metadata, long-lived media cache
//  âœ… PERFORMANCE: Background prefetching + batched updates
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
    
    // MARK: - Active Campaign Publishers
    @Published public var activeBannerCampaign: CampaignModel?
    @Published public var activeFloaterCampaign: CampaignModel?
    @Published public var activeCSATCampaign: CampaignModel?
    @Published public var activeSurveyCampaign: CampaignModel?
    @Published public var activeBottomSheetCampaign: CampaignModel?
    @Published public var activeModalCampaign: CampaignModel?
    @Published public var activeWidgetCampaign: CampaignModel?
    @Published public var activePIPCampaign: CampaignModel?
    @Published var activeScratchCampaign: CampaignModel?
    
    @Published public private(set) var activatedCampaigns: Set<String> = []
    
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
    
    private struct CampaignSnapshot {
        let campaigns: [CampaignModel]
        let fetchedAt: Date
    }

    // Add LRU cache with size limit
    private var lastKnownCampaigns: [String: CampaignSnapshot] = [:] {
        didSet {
            // âœ… Keep only last 10 screens
            if lastKnownCampaigns.count > 10 {
                let sortedByAge = lastKnownCampaigns.sorted {
                    $0.value.fetchedAt > $1.value.fetchedAt
                }
                let toRemove = sortedByAge.dropFirst(10)
                for (screen, _) in toRemove {
                    lastKnownCampaigns.removeValue(forKey: screen)
                }
                Logger.debug("ðŸ§¹ Pruned snapshot cache to 10 entries")
            }
        }
    }
    
    /// Activate a specific campaign by ID (for link-based triggering)
    public func activateCampaign(_ campaignId: String) {
        activatedCampaigns.insert(campaignId)
        Logger.info("⚡ Campaign \(campaignId) activated (specific)")
        updateActiveCampaigns()
    }

    /// Deactivate a specific campaign
    public func deactivateCampaign(_ campaignId: String) {
        activatedCampaigns.remove(campaignId)
        Logger.info("🔌 Campaign \(campaignId) deactivated")
        updateActiveCampaigns()
    }
    
    // MARK: - Story Presentation State
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
    
    // âœ… TOOLTIP SUPPORT
    public let elementRegistry = ElementRegistry()
    @Published public private(set) var tooltipManager: TooltipManager!
    
    var currentUserID: String?
    private var userAttributes: [String: AnyCodable] = [:]
    var currentScreen: String?
    
    // âœ… RACE CONDITION PROTECTION
    private var activeScreenRequest: (screenName: String, taskID: UUID)?
    private var screenTransitionID = UUID()
    
    private var dismissedCampaigns: Set<String> = []
    
    private let systemEvents: Set<String> = [
        "viewed", "clicked", "dismissed", "expanded",
        "minimized", "completed", "closed", "submitted",
        "story_completed", "story_dismissed", "story_opened",
        "slide_viewed"
    ]
    
    private var eventTrackingTasks: [String: Task<Void, Never>] = [:]
    
    // âœ… Prevent screen changes during capture
    private var isCapturing = false
    
    // âœ… PERFORMANCE: Batch campaign updates
    private struct ActiveCampaignsBatch {
        var banner: CampaignModel?
        var floater: CampaignModel?
        var csat: CampaignModel?
        var survey: CampaignModel?
        var bottomSheet: CampaignModel?
        var modal: CampaignModel?
        var widget: CampaignModel?
        var pip: CampaignModel?
        var scratchCard: CampaignModel?
    }
    
    // MARK: - Initialization
    private init() {
        setupLifecycleObservers()
    }
    
    // MARK: - Lifecycle Observers
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.elementRegistry.invalidateCache()
            Logger.debug("ðŸ“± Orientation changed - invalidated element cache")
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.elementRegistry.invalidateCache()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.elementRegistry.invalidateCache()
        }
    }
    
    @objc private func handleAppWillResignActive() {
        Logger.info("â ¸ï¸  App became inactive")
        pipPlayerManager.pause()
        storyManager.isPaused = true
    }
    
    @objc private func handleAppDidEnterBackground() {
        Logger.info("ðŸŒ™ App went to background")
    }
    
    @objc private func handleAppWillEnterForeground() {
        Logger.info("â˜€ï¸  App returning to foreground")
        
        // âœ… Re-fetch current screen (campaigns stay visible during fetch)
        if let currentScreen = currentScreen {
            Logger.info("ðŸ”„ Re-fetching campaigns for \(currentScreen) after foreground")
            trackScreen(currentScreen)
        }
        
        // Resume media playback
        if activePIPCampaign != nil {
            pipPlayerManager.play()
        }
        
        if storyPresentationState != nil {
            storyManager.isPaused = false
        }
    }
    
    func updateCurrentScreenReference(_ screenName: String) {
        guard currentScreen != screenName else { return }
        
        let previousScreen = currentScreen
        currentScreen = screenName
        
        if let previous = previousScreen {
            Logger.debug("ðŸ”„ Screen reference updated: \(previous) â†’ \(screenName)")
        }
    }
    
    // MARK: - ðŸŽ¯ Validated Screen Disappearance Handler
    
    public func hideAllCampaignsForDisappearingScreen(_ screenName: String) {
        Logger.info("ðŸš« Immediately hiding campaigns for disappearing screen: \(screenName)")
        
        // âœ… Hide all campaigns immediately
        hideAllCampaigns()
        
        // âœ… Clear dismissed state when leaving screen
        if !dismissedCampaigns.isEmpty {
            let count = dismissedCampaigns.count
            dismissedCampaigns.removeAll()
            Logger.info("ðŸ§¹ Cleared \(count) dismissed campaigns (screen lifecycle reset)")
        }
        
        // ✅ CRITICAL FIX: Clear activated campaigns to prevent "ghosting" on return
        if !activatedCampaigns.isEmpty {
            activatedCampaigns.removeAll()
            Logger.debug("🧹 Cleared activated campaigns")
        }
        
        // âœ… Clear current screen reference if it matches
        if currentScreen == screenName {
            currentScreen = nil
            Logger.debug("ðŸ§¹ Cleared currentScreen reference")
        }
    }
    
    // MARK: - Filtered Campaign Arrays
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
    
    public var scratchCardCampaigns: [CampaignModel] {
        safeFilteredCampaigns(type: "SCRT")
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
    
    // MARK: - Thread-Safe Filtering Helper (UPDATED)

    private func safeFilteredCampaigns(type: String) -> [CampaignModel] {
        let currentCampaigns = campaigns
        let currentDismissed = dismissedCampaigns
        let currentTrackedEvents = trackedEvents
        let currentActivated = activatedCampaigns  // ✅ NEW
        
        return currentCampaigns.filter { campaign in
            guard campaign.campaignType == type else { return false }
            
            // ✅ FIXED PRIORITY: Check activation BEFORE dismissal to allow re-triggering
            if let triggerEvent = campaign.triggerEvent, !triggerEvent.isEmpty {
                // Option 1: Campaign was specifically activated by ID
                if currentActivated.contains(campaign.id) {
                    return true
                }
                
                // Option 2: Trigger event was fired globally
                if currentTrackedEvents.contains(triggerEvent) {
                    return true
                }
            }
            
            // Skip dismissed campaigns (if not specifically activated)
            if currentDismissed.contains(campaign.id) {
                return false
            }
            
            // If trigger required but not met (and not specifically activated), hide
            if let triggerEvent = campaign.triggerEvent, !triggerEvent.isEmpty {
                return false
            }
            
            // No trigger requirement - always show
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
        // ✅ Clear specific activation
        activatedCampaigns.remove(campaignId)
        
        // Clear trigger event for retriggering
        if let campaign = campaigns.first(where: { $0.id == campaignId }),
           let triggerEvent = campaign.triggerEvent,
           !triggerEvent.isEmpty {
            
            trackedEvents.remove(triggerEvent)
            Logger.info("🔄 Cleared trigger event '\(triggerEvent)' for campaign \(campaignId)")
        }
        
        updateActiveCampaigns()
        Logger.info("🚫 Campaign \(campaignId) dismissed")
    }

    /// Determine if a campaign type should be retriggerable
    private func isRetriggerableCampaign(_ campaign: CampaignModel) -> Bool {
        // Campaigns with trigger events should always be retriggerable
        guard let triggerEvent = campaign.triggerEvent, !triggerEvent.isEmpty else {
            return false
        }
        
        // Define which campaign types can be retriggered
        let retriggerableTypes: Set<String> = ["SCRT", "TTP", "MOD", "BTS", "CSAT"]
        return retriggerableTypes.contains(campaign.campaignType)
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
        
        self.tooltipManager = TooltipManager(elementRegistry: elementRegistry)
        self.tooltipManager.setSDK(self)
        Logger.info("âœ… Tooltip system initialized")
        
        do {
            try await authManager?.authenticate()
            await retryPendingEvents()
            self.isInitialized = true
            Logger.info("âœ… AppStorys SDK initialized successfully")
        } catch {
            Logger.error("â Œ Failed to initialize AppStorys SDK", error: error)
        }
    }
    
    public func setUserAttributes(_ attributes: [String: Any]) {
        self.userAttributes = attributes.mapValues { AnyCodable($0) }
        Logger.debug("User attributes updated: \(attributes.keys.joined(separator: ", "))")
    }
    
    func cancelActiveScreenRequest() {
        if let active = activeScreenRequest {
            Logger.info("ðŸš« Cancelling active request for \(active.screenName)")
            activeScreenRequest = nil
        }
    }
    
    // âœ… PERFORMANCE FIX: Defer prefetching to background thread
    private func applyCampaignsToState(_ campaigns: [CampaignModel]) {
        self.campaigns = campaigns
        self.updateActiveCampaigns()
        
        // âœ… Prefetch asynchronously WITHOUT blocking main thread
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Prefetch story campaigns
            let storyCampaigns = await MainActor.run { self.storyCampaigns }
            for campaign in storyCampaigns {
                await self.storyManager.prefetchCampaign(campaign)
            }
            
            // Prefetch PIP campaigns
            let pipCampaigns = await MainActor.run { self.pipCampaigns }
            for pipCampaign in pipCampaigns {
                guard case let .pip(details) = pipCampaign.details else { continue }
                
                if let smallVideo = details.smallVideo {
                    await self.pipPlayerManager.prefetchVideo(smallVideo)
                }
                
                if let largeVideo = details.largeVideo,
                   largeVideo != details.smallVideo {
                    await self.pipPlayerManager.prefetchVideo(largeVideo)
                }
                
                await MainActor.run {
                    Logger.debug("ðŸ“º Prefetched PIP campaign: \(pipCampaign.id)")
                }
            }
            
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            await MainActor.run {
                Logger.debug("âœ… Background prefetch complete (\(String(format: "%.1f", elapsed))ms)")
            }
        }
    }
    
    private func updateCaptureState(_ enabled: Bool) {
        guard self.isScreenCaptureEnabled != enabled else {
            Logger.debug("â ­ Capture state unchanged: \(enabled)")
            return
        }
        
        Logger.info("ðŸ”„ Capture state changing: \(self.isScreenCaptureEnabled) â†’ \(enabled)")
        self.isScreenCaptureEnabled = enabled
        
        if enabled {
            if self.screenCaptureManager == nil {
                self.screenCaptureManager = ScreenCaptureManager(
                    authManager: self.authManager!,
                    baseURL: self.config?.baseURL ?? "https://users.appstorys.com",
                    elementRegistry: elementRegistry
                )
                Logger.info("ðŸ“¸ Screen capture manager initialized with element registry")
            }
        } else {
            self.screenCaptureManager = nil
            Logger.info("ðŸš« Screen capture manager disabled")
        }
    }
    
    // MARK: - Screen Capture API
    public func captureScreen() async throws {
        guard isInitialized else {
            throw AppStorysError.notInitialized
        }

        guard isScreenCaptureEnabled else {
            Logger.warning("âš ï¸  Screen capture is disabled by server")
            throw ScreenCaptureError.featureDisabled
        }

        guard let userId = currentUserID else {
            throw AppStorysError.notInitialized
        }

        guard let screenName = currentScreen else {
            Logger.warning("âš ï¸  No active screen to capture")
            throw ScreenCaptureError.noActiveScreen
        }

        // âœ… Notify SwiftUI hierarchy to trigger the live snapshot
        Logger.info("ðŸ“¸ Triggering SwiftUI snapshot for screen: \(screenName)")
        
        await MainActor.run {
            NotificationCenter.default.post(
                name: .AppStorysTriggerSnapshot,
                object: nil,
                userInfo: ["screen": screenName, "userId": userId]
            )
        }
    }

    // MARK: - ðŸŽ¯ Track Screen (Always Fetch Fresh, Snapshot for Fallback Only)

    public func trackScreen(
        _ screenName: String,
        completion: @escaping ([CampaignModel]) -> Void = { _ in }
    ) {
        guard isInitialized, let userID = currentUserID else {
            Logger.error("SDK not initialized")
            completion([])
            return
        }
        
        // âœ… CRITICAL: Ignore screen changes during capture operations
        if isCapturing {
            Logger.debug("ðŸ”’ Ignoring screen change during capture operation: \(screenName)")
            completion([])
            return
        }

        // âœ… Handle screen transition BEFORE state changes
        if let previousScreen = currentScreen, previousScreen != screenName {
            Logger.debug("Screen changed from \(previousScreen) → \(screenName)")
            
            // Clear session-specific state
            dismissedCampaigns.removeAll()
            activatedCampaigns.removeAll()  // ✅ ADD THIS
            Logger.debug("🧹 Cleared dismissed campaigns and activations for new screen")

            // Auto-dismiss tooltip on screen change
            if tooltipManager.isPresenting {
                Logger.info("ðŸ“Œ Auto-dismissing tooltip due to screen change")
                tooltipManager.dismiss()
            }
            
            // Invalidate element cache for new screen
            elementRegistry.invalidateCache()
        }
        
        // Generate transition ID for race condition protection
        let transitionID = UUID()
        screenTransitionID = transitionID
        
        // Update current screen
        currentScreen = screenName
        
        // âœ… ALWAYS fetch fresh from WebSocket (no caching logic)
        Logger.info("ðŸŒ  Fetching fresh campaigns for \(screenName)")
        
        let requestID = UUID()
        activeScreenRequest = (screenName, requestID)
        
        // Capture attributes snapshot
        let attributesCopy = self.userAttributes
        
        Task {
            do {
                // âœ… Fetch from WebSocket
                let result = try await campaignManager?.trackScreen(
                    screenName: screenName,
                    userID: userID,
                    attributes: attributesCopy
                ) ?? (campaigns: [], screenCaptureEnabled: false)
                
                await MainActor.run {
                    // âœ… Race condition protection
                    guard let active = self.activeScreenRequest,
                          active.screenName == screenName,
                          active.taskID == requestID,
                          self.screenTransitionID == transitionID,
                          self.currentScreen == screenName else {
                        Logger.warning("âš ï¸  Discarding stale response for \(screenName)")
                        
                        // âœ… Still store snapshot for potential network failure fallback
                        self.lastKnownCampaigns[screenName] = CampaignSnapshot(
                            campaigns: result.campaigns,
                            fetchedAt: Date()
                        )
                        completion([])
                        return
                    }
                    
                    // âœ… Update capture state
                    self.updateCaptureState(result.screenCaptureEnabled)
                    
                    // âœ… Store fresh snapshot BEFORE applying to UI
                    self.lastKnownCampaigns[screenName] = CampaignSnapshot(
                        campaigns: result.campaigns,
                        fetchedAt: Date()
                    )
                    
                    // âœ… Apply to UI state (prefetching now happens in background)
                    self.applyCampaignsToState(result.campaigns)
                    
                    if result.campaigns.isEmpty {
                        Logger.info("âœ… Screen tracked: \(screenName) - No campaigns available")
                    } else {
                        Logger.info("âœ… Screen tracked: \(screenName) - \(result.campaigns.count) campaigns loaded")
                    }
                    
                    completion(result.campaigns)
                }
                
            } catch {
                Logger.error("â Œ Failed to fetch campaigns", error: error)
                
                await MainActor.run {
                    // âœ… Race condition protection
                    guard let active = self.activeScreenRequest,
                          active.screenName == screenName,
                          active.taskID == requestID,
                          self.screenTransitionID == transitionID,
                          self.currentScreen == screenName else {
                        Logger.warning("âš ï¸  Discarding stale error for \(screenName)")
                        completion([])
                        return
                    }
                    
                    // âœ… CRITICAL: Use snapshot as fallback, NEVER clear existing campaigns
                    if let snapshot = self.lastKnownCampaigns[screenName] {
                        let age = Date().timeIntervalSince(snapshot.fetchedAt)
                        
                        if age < 300 { // 5 minutes max staleness
                            Logger.info("ðŸ“¦ Network failed, using snapshot (age: \(Int(age))s, \(snapshot.campaigns.count) campaigns)")
                            self.applyCampaignsToState(snapshot.campaigns)
                            completion(snapshot.campaigns)
                        } else {
                            Logger.warning("âš ï¸  Snapshot too stale (\(Int(age))s old), keeping existing campaigns visible")
                            // Don't clear campaigns - keep current state visible
                            completion(self.campaigns)
                        }
                    } else {
                        Logger.warning("âš ï¸  No snapshot available, keeping existing campaigns visible")
                        // Keep current campaigns state, don't clear
                        completion(self.campaigns)
                    }
                }
            }
        }
    }
    
    // MARK: - Track Event
    public func trackEvents(
        eventType: String,
        campaignId: String,
        metadata: [String: Any]? = nil
    ) async {
        guard isInitialized, let userID = currentUserID else {
            Logger.warning("âš ï¸  SDK not initialized, queuing event")
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
    
    public func triggerEvent(
        _ eventType: String,
        metadata: [String: Any]? = nil
    ) {
        Task {
            await self.trackEvents(
                eventType: eventType,
                campaignId: " ",
                metadata: metadata
            )
        }
    }

    // MARK: - Active Campaign Management (BATCHED)
    
    /// âœ… PERFORMANCE FIX: Update all campaigns in one transaction to reduce @Published spam
    private func updateActiveCampaigns() {
        // âœ… Build batch first (no @Published triggers yet)
        let batch = ActiveCampaignsBatch(
            banner: bannerCampaigns.first,
            floater: floaterCampaigns.first,
            csat: csatCampaigns.first,
            survey: surveyCampaigns.first,
            bottomSheet: bottomSheetCampaigns.first,
            modal: modalCampaigns.first,
            widget: widgetCampaigns.first,
            pip: pipCampaigns.first,
            scratchCard: scratchCardCampaigns.first
        )
        
        // âœ… Apply all at once (triggers ONE SwiftUI update cycle)
        activeBannerCampaign = batch.banner
        activeFloaterCampaign = batch.floater
        activeCSATCampaign = batch.csat
        activeSurveyCampaign = batch.survey
        activeBottomSheetCampaign = batch.bottomSheet
        activeModalCampaign = batch.modal
        activeWidgetCampaign = batch.widget
        activeScratchCampaign = batch.scratchCard
        // Handle PIP specially (check for ID changes)
        let newActivePIP = batch.pip
        if newActivePIP?.id != activePIPCampaign?.id {
            activePIPCampaign = newActivePIP
        } else {
            activePIPCampaign = newActivePIP
        }
        
        // Handle tooltip campaigns
        handleTooltipCampaigns()
        
        Logger.debug("Active campaigns updated (batched)")
    }
    
    /// Separate tooltip handling for clarity
    private func handleTooltipCampaigns() {
        let tooltipCampaigns = campaigns.filter { $0.campaignType == "TTP" }
        
        for tooltipCampaign in tooltipCampaigns {
            guard case .tooltip = tooltipCampaign.details else { continue }
            
            guard let screen = tooltipCampaign.screen,
                  screen.lowercased() == currentScreen?.lowercased() else {
                continue
            }
            
            guard !isCampaignDismissed(tooltipCampaign.id) else {
                continue
            }
            
            if let triggerEvent = tooltipCampaign.triggerEvent,
               !triggerEvent.isEmpty,
               !trackedEvents.contains(triggerEvent) {
                continue
            }
            
            presentTooltip(tooltipCampaign)
            break
        }
    }
    
    private func presentTooltip(_ campaign: CampaignModel) {
        
        guard isInitialized else {
            Logger.warning("âš ï¸  Cannot present tooltip - SDK not initialized yet")
            return
        }
        
        guard let tooltipManager = tooltipManager else {
            Logger.error("â Œ TooltipManager not available")
            return
        }

        guard let rootView = try? getCaptureView() else {
            Logger.error("â Œ Cannot present tooltip - no root view")
            return
        }
        
        Task {
            let result = await tooltipManager.presentWithWaiting(
                campaign: campaign,
                rootView: rootView,
                elementTimeout: 1.5
            )
            
            switch result {
            case .success(let stepCount):
                Logger.info("âœ… Tooltip presented with \(stepCount) steps")
                
            case .failure(.noTargetsFound(let missing)):
                Logger.error("â Œ Tooltip failed - missing elements: \(missing)")
                
                await trackEvents(
                    eventType: "presentation_failed",
                    campaignId: campaign.id,
                    metadata: [
                        "reason": "missing_elements",
                        "missing_targets": missing.joined(separator: ","),
                        "screen": currentScreen ?? "unknown"
                    ]
                )
                
            case .failure(.invalidCampaign):
                Logger.error("â Œ Invalid tooltip campaign")
                
            case .failure(.alreadyPresenting):
                Logger.debug("â ­ Tooltip already presenting, skipping")
                
            @unknown default:
                Logger.error("â Œ Unknown tooltip presentation error")
            }
        }
    }
    
    // MARK: - Public Campaign Control Methods
    
    /// Hides all active campaigns
    public func hideAllCampaigns() {
        activeBannerCampaign = nil
        activeFloaterCampaign = nil
        activeCSATCampaign = nil
        activeSurveyCampaign = nil
        activeBottomSheetCampaign = nil
        activeModalCampaign = nil
        activeWidgetCampaign = nil
        activePIPCampaign = nil
        
        tooltipManager?.dismiss()
        
        Logger.debug("All campaigns hidden")
    }
    
    public func hidePIPCampaign() {
        activePIPCampaign = nil
        Logger.debug("PiP campaign hidden")
    }
    
    // MARK: - Story Presentation
    public func presentStory(campaign: StoryCampaign, initialGroupIndex: Int = 0) {
        storyPresentationState = StoryPresentationState(
            campaign: campaign,
            initialIndex: initialGroupIndex
        )
        storyManager.openStory(campaign: campaign, initialGroupIndex: initialGroupIndex)
        Logger.info("ðŸ“– Presenting story campaign: \(campaign.id)")
    }
    
    public func dismissStory() {
        storyPresentationState = nil
        storyManager.closeStory()
        Logger.info("ðŸ“• Dismissed story")
    }
    
    // MARK: - Tooltip Control
    public var isTooltipPresenting: Bool {
        return tooltipManager?.isPresenting ?? false
    }
    
    public func dismissTooltip() {
        tooltipManager?.dismiss()
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
        
        // âœ… Just re-fetch (no cache invalidation needed)
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
        activeScreenRequest = nil
        isScreenCaptureEnabled = false
        screenCaptureManager = nil
        lastKnownCampaigns.removeAll()
        
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
        lastKnownCampaigns.removeAll()
        
        Logger.info("AppStorys SDK reset to initial state")
    }
    
    deinit {
        elementRegistry.stopObserving()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Debug Helpers
extension AppStorys {
    public var debugInfo: String {
        let snapshotInfo = lastKnownCampaigns.map { screen, snapshot in
            let age = Int(Date().timeIntervalSince(snapshot.fetchedAt))
            return "  â€¢ \(screen): \(snapshot.campaigns.count) campaigns (\(age)s old)"
        }.joined(separator: "\n")
        
        return """
        AppStorys SDK Debug Info
        
        Initialized: \(isInitialized)
        User ID: \(currentUserID ?? "nil")
        Current Screen: \(currentScreen ?? "nil")
        Active Request: \(activeScreenRequest?.screenName ?? "none")
        Transition ID: \(screenTransitionID)
        Total Campaigns: \(campaigns.count)
        Tracked Events: \(trackedEvents.count)
        Dismissed Campaigns: \(dismissedCampaigns.count)
        Snapshots: \(lastKnownCampaigns.count) screens cached
        Screen Capture: \(isScreenCaptureEnabled ? "âœ… ENABLED" : "â Œ disabled")
        Tooltip System: \(tooltipManager != nil ? "âœ… READY" : "â Œ not initialized")
        
        Active Campaigns:
        - Banner: \(activeBannerCampaign != nil ? "âœ…" : "â Œ")
        - Floater: \(activeFloaterCampaign != nil ? "âœ…" : "â Œ")
        - PIP: \(activePIPCampaign != nil ? "âœ…" : "â Œ")
        - CSAT: \(activeCSATCampaign != nil ? "âœ…" : "â Œ")
        - Survey: \(activeSurveyCampaign != nil ? "âœ…" : "â Œ")
        - Bottom Sheet: \(activeBottomSheetCampaign != nil ? "âœ…" : "â Œ")
        - Modal: \(activeModalCampaign != nil ? "âœ…" : "â Œ")
        - Widget: \(activeWidgetCampaign != nil ? "âœ…" : "â Œ")
        - Tooltip: \(isTooltipPresenting ? "âœ… PRESENTING" : "â Œ")
        
        Campaign Snapshots:
        \(snapshotInfo.isEmpty ? "  (none)" : snapshotInfo)
        
        Tracked Events: \(Array(trackedEvents).joined(separator: ", "))
        Dismissed IDs: \(Array(dismissedCampaigns).joined(separator: ", "))
        """
    }
    
    public func printDebugInfo() {
        print(debugInfo)
    }
}

// MARK: - CSAT Response Capture
extension AppStorys {
    
    /// Capture structured CSAT response (rating + feedback)
    /// âœ… Uses dedicated endpoint: /capture-csat-response/
    /// âœ… Supports offline queueing
    /// âœ… Validates data before sending
    public func captureCsatResponse(
        csatId: String,
        rating: Int,
        feedbackOption: String? = nil,
        additionalComments: String? = nil
    ) async throws {
        guard isInitialized, let userID = currentUserID else {
            throw AppStorysError.notInitialized
        }
        
        // Validate rating range
        guard (1...5).contains(rating) else {
            Logger.error("Invalid rating: \(rating). Must be 1-5")
            throw AppStorysError.invalidParameter("Rating must be between 1 and 5")
        }
        
        Logger.info("ðŸ“Š Capturing CSAT response: rating=\(rating), csat=\(csatId)")
        
        // Check network connectivity
        let connectivityResult = await checkNetworkConnectivity()
        
        if !connectivityResult {
            // Queue for later if offline
            Logger.warning("âš ï¸  Offline - queueing CSAT response")
            await pendingEventManager.saveCsatResponse(
                csatId: csatId,
                userId: userID,
                rating: rating,
                feedbackOption: feedbackOption,
                additionalComments: additionalComments
            )
            return
        }
        
        // Send to backend
        do {
            try await submitCsatResponse(
                csatId: csatId,
                userId: userID,
                rating: rating,
                feedbackOption: feedbackOption,
                additionalComments: additionalComments
            )
            
            Logger.info("âœ… CSAT response captured successfully")
            
        } catch {
            Logger.error("â Œ Failed to capture CSAT response", error: error)
            
            // Queue for retry
            await pendingEventManager.saveCsatResponse(
                csatId: csatId,
                userId: userID,
                rating: rating,
                feedbackOption: feedbackOption,
                additionalComments: additionalComments
            )
            
            throw error
        }
    }
    
    /// Internal: Submit CSAT response to backend
    private func submitCsatResponse(
        csatId: String,
        userId: String,
        rating: Int,
        feedbackOption: String?,
        additionalComments: String?
    ) async throws {
        let backendURL = config?.baseURL.replacingOccurrences(of: "users", with: "backend")
            ?? "https://backend.appstorys.com"
        
        guard let url = URL(string: "\(backendURL)/api/v1/campaigns/capture-csat-response/") else {
            throw AppStorysError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth header
        guard let authManager = authManager else {
            throw AppStorysError.notInitialized
        }
        
        let token = try await authManager.getAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Build request body
        let requestBody = CsatResponseRequest(
            csat: csatId,
            userId: userId,
            rating: rating,
            feedbackOption: feedbackOption,
            additionalComments: additionalComments
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // Log request
        Logger.debug("ðŸ“¤ POST \(url.absoluteString)")
        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            Logger.debug("ðŸ“¦ Request Body: \(bodyString)")
        }
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppStorysError.invalidResponse
        }
        
        Logger.debug("ðŸ“¥ Response: \(httpResponse.statusCode)")
        
        // Handle response
        guard (200...201).contains(httpResponse.statusCode) else {
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.error("â Œ Server error response: \(responseString)")
            }
            throw AppStorysError.serverError(httpResponse.statusCode)
        }
        
        // Optionally decode success response
        if let result = try? JSONDecoder().decode(CsatResponseResult.self, from: data) {
            Logger.debug("âœ… Server response: \(result.message ?? "Success")")
        }
    }
    
    /// Check network connectivity (placeholder - implement properly)
    private func checkNetworkConnectivity() async -> Bool {
        // TODO: Implement proper network reachability check
        // For now, always return true
        return true
    }
}

// MARK: - Error Extension
extension AppStorysError {
    static func invalidParameter(_ message: String) -> AppStorysError {
        return .taskGroupFailure(message)
    }
}
