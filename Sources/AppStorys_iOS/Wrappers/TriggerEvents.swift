//
//  TriggerEvents.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//


import SwiftUI

// MARK: - Main Public API Extension
public extension AppStorys {
    
    // MARK: - Event Triggering (Static Methods)
    
    /// Triggers a custom AppStorys event
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
            await shared.trackEvents(
                eventType: eventType,
                campaignId: "",
                metadata: metadata
            )
        }
    }
    
    /// Triggers a campaign-specific event
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
            await shared.trackEvents(
                eventType: eventType,
                campaignId: campaignId,
                metadata: metadata
            )
        }
    }
}
