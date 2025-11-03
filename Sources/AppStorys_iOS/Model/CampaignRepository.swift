//
//  CampaignRepository.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//


//
//  CampaignRepository.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Proper cache management with screen lifecycle
//

import Foundation

@MainActor
class CampaignRepository: ObservableObject {
    
    // MARK: - Cache Storage
    
    /// Network response cache (per screen)
    private var screenCampaigns: [String: ScreenCampaignState] = [:]
    
    /// Timestamp tracking for TTL
    private var fetchTimestamps: [String: Date] = [:]
    
    struct ScreenCampaignState {
        let screenName: String
        let campaigns: [CampaignModel]
        let fetchedAt: Date
        var isActive: Bool  // ← False when backgrounded or navigated away
    }
    
    // MARK: - Configuration
    
    private let inlineCacheDuration: TimeInterval = .infinity  // Until navigation
    private let overlayCacheDuration: TimeInterval = 15 * 60   // 15 minutes
    
    private let userDefaults = UserDefaults.standard
    private let persistenceKey = "appstorys_campaign_cache"
    
    // MARK: - Public API
    
    /// Store campaigns for a screen (called after successful fetch)
    func storeCampaigns(_ campaigns: [CampaignModel], for screenName: String) {
        let state = ScreenCampaignState(
            screenName: screenName,
            campaigns: campaigns,
            fetchedAt: Date(),
            isActive: true
        )
        
        screenCampaigns[screenName] = state
        fetchTimestamps[screenName] = Date()
        
        Logger.debug("💾 Cached \(campaigns.count) campaigns for \(screenName)")
    }
    
    /// Get cached campaigns for a screen
    /// - Parameter allowStale: If true, return cached data even if expired (fallback for offline)
    func getCampaigns(for screenName: String, allowStale: Bool = false) -> [CampaignModel]? {
        guard let state = screenCampaigns[screenName] else {
            return nil
        }
        
        // Check if cache is still valid
        if !allowStale {
            guard isCacheValid(for: screenName, state: state) else {
                Logger.debug("⏰ Cache expired for \(screenName)")
                return nil
            }
        } else if !isCacheValid(for: screenName, state: state) {
            Logger.debug("📦 Serving stale cache for \(screenName) (fallback)")
        }
        
        Logger.debug("✅ Serving \(state.campaigns.count) campaigns from cache")
        return state.campaigns
    }
    
    /// Check if we have valid cached data
    func hasCachedCampaigns(for screenName: String) -> Bool {
        guard let state = screenCampaigns[screenName] else {
            return false
        }
        return isCacheValid(for: screenName, state: state)
    }
    
    // MARK: - Screen Lifecycle Management
    
    /// Mark screen as active (user is viewing it)
    func markScreenActive(_ screenName: String) {
        guard var state = screenCampaigns[screenName] else { return }
        state.isActive = true
        screenCampaigns[screenName] = state
        Logger.debug("👁️ Screen marked active: \(screenName)")
    }
    
    /// Mark screen as inactive (user navigated away, but KEEP cache for back navigation)
    func markScreenInactive(_ screenName: String) {
        guard var state = screenCampaigns[screenName] else { return }
        state.isActive = false
        screenCampaigns[screenName] = state
        Logger.debug("💤 Screen marked inactive (preserving cache): \(screenName)")
    }
    
    /// Clean up caches for inactive screens (called on app background)
    func cleanupInactiveScreens() {
        let inactiveScreens = screenCampaigns.filter { !$0.value.isActive }.map { $0.key }
        var removedCount = 0
        
        for screen in inactiveScreens {
            // Only remove if cache is expired
            if let state = screenCampaigns[screen],
               !isCacheValid(for: screen, state: state) {
                screenCampaigns.removeValue(forKey: screen)
                fetchTimestamps.removeValue(forKey: screen)
                removedCount += 1
            }
        }
        
        if removedCount > 0 {
            Logger.debug("🧹 Cleaned up \(removedCount) expired inactive screens")
        }
    }
    
    // MARK: - Lifecycle Management
    
    /// Called when app backgrounds - preserve state
    func handleAppBackground() {
        Logger.info("🌙 App backgrounded - preserving campaign cache")
        
        // Mark all as inactive but DON'T clear
        for (screen, var state) in screenCampaigns {
            state.isActive = false
            screenCampaigns[screen] = state
        }
        
        // Persist to storage
        persistToStorage()
    }
    
    /// Called when app foregrounds - restore state
    func handleAppForeground() {
        Logger.info("☀️ App foregrounded - restoring campaign cache")
        
        // Mark all as active again
        for (screen, var state) in screenCampaigns {
            state.isActive = true
            screenCampaigns[screen] = state
        }
        
        // Check if any caches expired while backgrounded
        cleanupExpiredCaches()
    }
    
    /// Called when user navigates away from a screen
    func clearCampaigns(for screenName: String) {
        Logger.debug("🧹 Clearing campaigns for \(screenName) (navigation)")
        screenCampaigns.removeValue(forKey: screenName)
        fetchTimestamps.removeValue(forKey: screenName)
    }
    
    // MARK: - Private Helpers
    
    private func isCacheValid(for screenName: String, state: ScreenCampaignState) -> Bool {
        let now = Date()
        let age = now.timeIntervalSince(state.fetchedAt)
        
        // Separate inline vs overlay campaigns
        let hasInline = state.campaigns.contains { isInlineCampaign($0) }
        let hasOverlay = state.campaigns.contains { !isInlineCampaign($0) }
        
        // Inline campaigns: cached until navigation
        if hasInline {
            return true  // Never expire by time
        }
        
        // Overlay campaigns: 15 min TTL
        if hasOverlay {
            return age < overlayCacheDuration
        }
        
        return false
    }
    
    private func isInlineCampaign(_ campaign: CampaignModel) -> Bool {
        return ["WID", "STR"].contains(campaign.campaignType)
    }
    
    private func cleanupExpiredCaches() {
        let now = Date()
        var expiredScreens: [String] = []
        
        for (screen, state) in screenCampaigns {
            if !isCacheValid(for: screen, state: state) {
                expiredScreens.append(screen)
            }
        }
        
        for screen in expiredScreens {
            screenCampaigns.removeValue(forKey: screen)
            fetchTimestamps.removeValue(forKey: screen)
        }
        
        if !expiredScreens.isEmpty {
            Logger.debug("🧹 Cleaned up \(expiredScreens.count) expired caches")
        }
    }
    
    // MARK: - Persistence
    
    private func persistToStorage() {
        // Simple persistence for now - just save screen names
        let screenNames = Array(screenCampaigns.keys)
        userDefaults.set(screenNames, forKey: persistenceKey)
        Logger.debug("💾 Persisted \(screenNames.count) screen states")
    }
    
    func restoreFromStorage() {
        // On app launch, we don't restore full campaigns
        // Just log that we have cached state
        if let screenNames = userDefaults.array(forKey: persistenceKey) as? [String] {
            Logger.info("🔄 Found \(screenNames.count) cached screens from last session")
        }
    }
}