//
//  AppStorys.swift - Enhanced Race Condition Protection
//
//  ✅ ROOT-LEVEL SOLUTION: Guards against stale lifecycle events
//  ✅ ZERO BOILERPLATE: No .onDisappear needed in views
//  ✅ BELT-AND-SUSPENDERS: Validates screen identity before dismissal
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
    
    // MARK: - Repository Layer
    let campaignRepository = CampaignRepository()
    
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
    
    // ✅ TOOLTIP SUPPORT
    public let elementRegistry = ElementRegistry()
    @Published public private(set) var tooltipManager: TooltipManager!
    
    var currentUserID: String?
    private var userAttributes: [String: AnyCodable] = [:]
    var currentScreen: String?
    
    // ✅ RACE CONDITION PROTECTION: Track transition state
    private var activeScreenRequest: (screenName: String, taskID: UUID)?
    private var screenTransitionID = UUID()  // ✅ NEW: Prevents stale responses
    
    private var dismissedCampaigns: Set<String> = []
    
    private let systemEvents: Set<String> = [
        "viewed", "clicked", "dismissed", "expanded",
        "minimized", "completed", "closed", "submitted",
        "story_completed", "story_dismissed", "story_opened",
        "slide_viewed"
    ]
    
    private var eventTrackingTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    private init() {
        campaignRepository.restoreFromStorage()
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
            Logger.debug("🔄 Orientation changed - invalidated element cache")
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
        Logger.info("⏸️ App became inactive")
        pipPlayerManager.pause()
        storyManager.isPaused = true
    }
    
    @objc private func handleAppDidEnterBackground() {
        Logger.info("🌙 App went to background")
        campaignRepository.handleAppBackground()
        campaignRepository.cleanupInactiveScreens()
    }
    
    @objc private func handleAppWillEnterForeground() {
        Logger.info("☀️ App returning to foreground")
        campaignRepository.handleAppForeground()
        
        if activePIPCampaign != nil {
            pipPlayerManager.play()
        }
        
        if storyPresentationState != nil {
            storyManager.isPaused = false
        }
    }
    
    // MARK: - 🎯 NEW: Validated Screen Disappearance Handler
    
    /// Handles screen disappearance with identity validation
    /// ✅ RACE-SAFE: Only hides campaigns if the disappeared screen is still current
    /// ✅ CALL THIS: From .onDisappear in views (optional but recommended)
    public func handleScreenDisappeared(_ screenName: String) {
        guard currentScreen == screenName else {
            Logger.debug("🔸 Ignored disappearance for \(screenName) — current: \(currentScreen ?? "nil")")
            return
        }
        
        Logger.debug("📴 Hiding campaigns for disappeared screen: \(screenName)")
        hideAllCampaigns()
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
            Logger.debug("🚫 Campaign \(campaign.id) is dismissed, skipping")
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
        Logger.info("🚫 Campaign \(campaignId) marked as dismissed for this session")
    }
    
    public func isCampaignDismissed(_ campaignId: String) -> Bool {
        dismissedCampaigns.contains(campaignId)
    }
    
    // MARK: - Trigger Event Logic
    public func addTrackedEvent(_ eventName: String) {
        trackedEvents.insert(eventName)
        Logger.info("✅ Event tracked: \(eventName)")
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
        Logger.info("🚀 Initializing AppStorys SDK...")
        
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
        Logger.info("✅ Tooltip system initialized")
        
        do {
            try await authManager?.authenticate()
            await retryPendingEvents()
            self.isInitialized = true
            Logger.info("✅ AppStorys SDK initialized successfully")
        } catch {
            Logger.error("❌ Failed to initialize AppStorys SDK", error: error)
        }
    }
    
    public func setUserAttributes(_ attributes: [String: Any]) {
        self.userAttributes = attributes.mapValues { AnyCodable($0) }
        Logger.debug("User attributes updated: \(attributes.keys.joined(separator: ", "))")
    }

    // MARK: - 🎯 ENHANCED Track Screen (Race-Safe)
    
    public func trackScreen(
        _ screenName: String,
        completion: @escaping ([CampaignModel]) -> Void = { _ in }
    ) {
        guard isInitialized, let userID = currentUserID else {
            Logger.error("SDK not initialized")
            completion([])
            return
        }

        // ✅ CRITICAL FIX: Handle screen transition BEFORE state changes
        if let previousScreen = currentScreen, previousScreen != screenName {
            Logger.debug("Screen changed from \(previousScreen) → \(screenName)")
            
            // Mark old screen inactive
            campaignRepository.markScreenInactive(previousScreen)
            
            // ✅ STEP 1: Clear dismissed campaigns FIRST (allows new campaigns to show)
            dismissedCampaigns.removeAll()
            Logger.debug("🧹 Cleared dismissed campaigns for new screen")
            
            // ✅ STEP 2: Dismiss tooltip (preserves tracking)
            if tooltipManager.isPresenting {
                Logger.info("📌 Auto-dismissing tooltip due to screen change")
                tooltipManager.dismiss()
            }
            
            // ✅ STEP 3: Invalidate element cache
            elementRegistry.invalidateCache()
            
            // ✅ STEP 4: Use validated dismissal (instead of direct hideAllCampaigns)
            handleScreenDisappeared(previousScreen)
        }
        
        // ✅ Generate new transition ID to invalidate stale responses
        let transitionID = UUID()
        screenTransitionID = transitionID
        
        currentScreen = screenName
        campaignRepository.markScreenActive(screenName)
        
        // Check cache AFTER dismissedCampaigns is cleared
        if let cachedCampaigns = campaignRepository.getCampaigns(for: screenName, allowStale: false) {
            Logger.info("⚡ Serving fresh cache for \(screenName) (\(cachedCampaigns.count) campaigns)")
            applyCampaignsToState(cachedCampaigns)
            completion(cachedCampaigns)
            return
        }
        
        let requestID = UUID()
        activeScreenRequest = (screenName, requestID)
        
        Logger.info("🌐 Fetching campaigns from network for \(screenName) [Request: \(requestID)]")
        
        let attributesCopy = self.userAttributes
        
        Task {
            do {
                let result = try await campaignManager?.trackScreen(
                    screenName: screenName,
                    userID: userID,
                    attributes: attributesCopy
                ) ?? (campaigns: [], screenCaptureEnabled: false)
                
                await MainActor.run {
                    // ✅ ENHANCED VALIDATION: Check both request ID and transition ID
                    guard let active = self.activeScreenRequest,
                          active.screenName == screenName,
                          active.taskID == requestID else {
                        Logger.warning("⚠️ Discarding stale response for \(screenName) [Request: \(requestID)]")
                        self.campaignRepository.storeCampaigns(result.campaigns, for: screenName)
                        completion([])
                        return
                    }
                    
                    guard self.screenTransitionID == transitionID else {
                        Logger.warning("⚠️ Ignoring outdated campaign load for \(screenName) - newer screen loaded")
                        self.campaignRepository.storeCampaigns(result.campaigns, for: screenName)
                        completion([])
                        return
                    }
                    
                    guard self.currentScreen == screenName else {
                        Logger.warning("⚠️ Screen changed during fetch: \(screenName) → \(self.currentScreen ?? "none")")
                        self.campaignRepository.storeCampaigns(result.campaigns, for: screenName)
                        completion([])
                        return
                    }
                    
                    self.updateCaptureState(result.screenCaptureEnabled)
                    self.campaignRepository.storeCampaigns(result.campaigns, for: screenName)
                    self.applyCampaignsToState(result.campaigns)
                    
                    if result.campaigns.isEmpty {
                        Logger.info("✅ Screen tracked: \(screenName) - No campaigns available")
                    } else {
                        Logger.info("✅ Screen tracked: \(screenName) - \(result.campaigns.count) campaigns loaded")
                    }
                    
                    completion(result.campaigns)
                }
                
            } catch {
                Logger.error("❌ Failed to fetch campaigns", error: error)
                
                await MainActor.run {
                    guard let active = self.activeScreenRequest,
                          active.screenName == screenName,
                          active.taskID == requestID,
                          self.screenTransitionID == transitionID else {
                        Logger.warning("⚠️ Discarding stale error for \(screenName)")
                        completion([])
                        return
                    }
                    
                    guard self.currentScreen == screenName else {
                        Logger.warning("⚠️ Screen changed during error: \(screenName) → \(self.currentScreen ?? "none")")
                        completion([])
                        return
                    }
                    
                    if let staleCampaigns = self.campaignRepository.getCampaigns(
                        for: screenName,
                        allowStale: true
                    ) {
                        Logger.info("📦 Network failed, serving stale cache (\(staleCampaigns.count) campaigns)")
                        self.applyCampaignsToState(staleCampaigns)
                        completion(staleCampaigns)
                    } else {
                        Logger.warning("⚠️ No cache available, serving empty")
                        self.campaigns = []
                        self.updateActiveCampaigns()
                        completion([])
                    }
                }
            }
        }
    }
    
    func cancelActiveScreenRequest() {
        if let active = activeScreenRequest {
            Logger.info("🚫 Cancelling active request for \(active.screenName)")
            activeScreenRequest = nil
        }
    }
    
    private func applyCampaignsToState(_ campaigns: [CampaignModel]) {
        self.campaigns = campaigns
        self.updateActiveCampaigns()
        
        for campaign in self.storyCampaigns {
            storyManager.prefetchCampaign(campaign)
        }
        
        for pipCampaign in self.pipCampaigns {
            guard case let .pip(details) = pipCampaign.details else { continue }
            
            if let smallVideo = details.smallVideo {
                pipPlayerManager.prefetchVideo(smallVideo)
            }
            
            if let largeVideo = details.largeVideo,
               largeVideo != details.smallVideo {
                pipPlayerManager.prefetchVideo(largeVideo)
            }
            
            Logger.debug("📄 Prefetching PIP campaign: \(pipCampaign.id)")
        }
    }
    
    private func updateCaptureState(_ enabled: Bool) {
        guard self.isScreenCaptureEnabled != enabled else {
            Logger.debug("⏭ Capture state unchanged: \(enabled)")
            return
        }
        
        Logger.info("🔄 Capture state changing: \(self.isScreenCaptureEnabled) → \(enabled)")
        self.isScreenCaptureEnabled = enabled
        
        if enabled {
            if self.screenCaptureManager == nil {
                self.screenCaptureManager = ScreenCaptureManager(
                    authManager: self.authManager!,
                    baseURL: self.config?.baseURL ?? "https://users.appstorys.com",
                    elementRegistry: elementRegistry
                )
                Logger.info("📸 Screen capture manager initialized with element registry")
            }
        } else {
            self.screenCaptureManager = nil
            Logger.info("🚫 Screen capture manager disabled")
        }
    }
    
    // MARK: - Screen Capture API
    public func captureScreen(from view: UIView) async throws {
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
            Logger.warning("⚠️ SDK not initialized, queuing event")
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
    public func triggerEvent(
        _ eventType: String,
        metadata: [String: Any]? = nil
    ) {
        // Automatically run asynchronously
        Task {
            await self.trackEvents(
                eventType: eventType,
                campaignId: " ",
                metadata: metadata
            )
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
        
        let newActivePIP = pipCampaigns.first
        if newActivePIP?.id != activePIPCampaign?.id {
            activePIPCampaign = newActivePIP
            
            if let pipCampaign = newActivePIP,
               case let .pip(details) = pipCampaign.details {
                
                if let smallVideo = details.smallVideo {
                    pipPlayerManager.prefetchVideo(smallVideo)
                }
                
                if let largeVideo = details.largeVideo,
                   largeVideo != details.smallVideo {
                    pipPlayerManager.prefetchVideo(largeVideo)
                }
                
                Logger.debug("🚀 Prefetching active PIP campaign: \(pipCampaign.id)")
            }
        } else {
            activePIPCampaign = newActivePIP
        }
        
        // Handle tooltip campaigns
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
        
        Logger.debug("Active campaigns updated")
    }
    
    private func presentTooltip(_ campaign: CampaignModel) {
        
        guard isInitialized else {
            Logger.warning("⚠️ Cannot present tooltip - SDK not initialized yet")
            return
        }
        
        guard let tooltipManager = tooltipManager else {
            Logger.error("❌ TooltipManager not available")
            return
        }

        guard let rootView = try? getCaptureView() else {
            Logger.error("❌ Cannot present tooltip - no root view")
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
                Logger.info("✅ Tooltip presented with \(stepCount) steps")
                
            case .failure(.noTargetsFound(let missing)):
                Logger.error("❌ Tooltip failed - missing elements: \(missing)")
                
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
                Logger.error("❌ Invalid tooltip campaign")
                
            case .failure(.alreadyPresenting):
                Logger.debug("⏭ Tooltip already presenting, skipping")
                
            @unknown default:
                Logger.error("❌ Unknown tooltip presentation error")
            }
        }
    }
    
    // MARK: - Public Campaign Control Methods
    
    /// Hides all active campaigns
    /// ⚠️ LEGACY METHOD: Consider using handleScreenDisappeared() instead for race-safety
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
        Logger.info("📖 Presenting story campaign: \(campaign.id)")
    }
    
    public func dismissStory() {
        storyPresentationState = nil
        storyManager.closeStory()
        Logger.info("📕 Dismissed story")
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
    
    deinit {
        elementRegistry.stopObserving()
        NotificationCenter.default.removeObserver(self)
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
        Active Request: \(activeScreenRequest?.screenName ?? "none")
        Transition ID: \(screenTransitionID)
        Total Campaigns: \(campaigns.count)
        Tracked Events: \(trackedEvents.count)
        Dismissed Campaigns: \(dismissedCampaigns.count)
        Screen Capture: \(isScreenCaptureEnabled ? "✅ ENABLED" : "❌ disabled")
        Tooltip System: \(tooltipManager != nil ? "✅ READY" : "❌ not initialized")
        
        Active Campaigns:
        - Banner: \(activeBannerCampaign != nil ? "✅" : "❌")
        - Floater: \(activeFloaterCampaign != nil ? "✅" : "❌")
        - PIP: \(activePIPCampaign != nil ? "✅" : "❌")
        - CSAT: \(activeCSATCampaign != nil ? "✅" : "❌")
        - Survey: \(activeSurveyCampaign != nil ? "✅" : "❌")
        - Bottom Sheet: \(activeBottomSheetCampaign != nil ? "✅" : "❌")
        - Modal: \(activeModalCampaign != nil ? "✅" : "❌")
        - Widget: \(activeWidgetCampaign != nil ? "✅" : "❌")
        - Tooltip: \(isTooltipPresenting ? "✅ PRESENTING" : "❌")
        
        Tracked Events: \(Array(trackedEvents).joined(separator: ", "))
        Dismissed IDs: \(Array(dismissedCampaigns).joined(separator: ", "))
        """
    }
    
    public func printDebugInfo() {
        print(debugInfo)
    }
}
