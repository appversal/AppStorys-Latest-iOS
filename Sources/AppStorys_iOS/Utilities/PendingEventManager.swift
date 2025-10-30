//
//  File.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 07/10/25.
//

import Foundation

/// Manages offline event queue - stores events when network unavailable
actor PendingEventManager {
    private let userDefaults = UserDefaults.standard
    private let key = "appstorys_pending_events"
    
    struct PendingEvent: Codable {
        let campaignId: String?
        let event: String
        let metadata: [String: AnyCodable]?
        let timestamp: Date
    }
    
    func save(campaignId: String?, event: String, metadata: [String: AnyCodable]?) {
        var events = getAll()
        events.append(PendingEvent(
            campaignId: campaignId,
            event: event,
            metadata: metadata,
            timestamp: Date()
        ))
        
        if let data = try? JSONEncoder().encode(events) {
            userDefaults.set(data, forKey: key)
            Logger.info("💾 Event saved for retry: \(event)")
        }
    }
    
    func getAll() -> [PendingEvent] {
        guard let data = userDefaults.data(forKey: key),
              let events = try? JSONDecoder().decode([PendingEvent].self, from: data) else {
            return []
        }
        return events
    }
    
    func clear() {
        userDefaults.removeObject(forKey: key)
        Logger.info("🗑️ Pending events cleared")
    }
}
