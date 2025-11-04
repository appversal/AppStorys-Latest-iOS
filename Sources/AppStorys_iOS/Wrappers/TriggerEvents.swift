//
//  TriggerEvents.swift
//  AppStorys_iOS
//
//  ✅ AUTO-WAITS: All methods wait for SDK initialization
//  ✅ THREAD-SAFE: Properly queued operations
//

import SwiftUI

// MARK: - Main Public API Extension
public extension AppStorys {
    
    // MARK: - Event Triggering (Static Methods)
    
    /// Triggers a custom AppStorys event
    /// ✅ Automatically waits for SDK to be ready
    /// - Parameters:
    ///   - eventType: Name of the event (e.g., "Loan Approved", "Purchase Completed")
    ///   - metadata: Optional additional data to attach to the event
    ///
    /// Example:
    /// ```swift
    /// Button("Complete Purchase") {
    ///     AppStorys.triggerEvent("Purchase Completed", metadata: ["amount": 99.99])
    /// }
    /// ```
    static func triggerEvent(
        _ eventType: String,
        metadata: [String: Any]? = nil
    ) {
        Task {
            // ✅ Auto-wait for initialization
            await shared.waitForInitialization()
            
            await shared.trackEvents(
                eventType: eventType,
                campaignId: " ", // Space indicates no specific campaign
                metadata: metadata
            )
        }
    }
    
    /// Triggers a campaign-specific event
    /// ✅ Automatically waits for SDK to be ready
    /// - Parameters:
    ///   - eventType: Name of the event
    ///   - campaignId: ID of the associated campaign
    ///   - metadata: Optional additional data
    ///
    /// Example:
    /// ```swift
    /// AppStorys.triggerEvent("Button Clicked", campaignId: "camp_123")
    /// ```
    static func triggerEvent(
        _ eventType: String,
        campaignId: String,
        metadata: [String: Any]? = nil
    ) {
        Task {
            // ✅ Auto-wait for initialization
            await shared.waitForInitialization()
            
            await shared.trackEvents(
                eventType: eventType,
                campaignId: campaignId,
                metadata: metadata
            )
        }
    }
}
