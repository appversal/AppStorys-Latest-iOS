//
//  WidgetSlot.swift
//  AppStorys_iOS
//
//  ✅ ENHANCED: Position-based widget system with capture tagging
//

import SwiftUI

public extension AppStorys {
    
    // MARK: - Single Widget at Position
    
    /// Display a widget at a specific position
    /// - Parameter position: The position identifier that matches backend campaign.position
    ///
    /// Example:
    /// ```swift
    /// AppStorys.Widget(position: "top_banner")
    ///     .captureAppStorysWidgetTag("top_banner")
    /// ```
    struct Widget: View {
        @ObservedObject private var sdk = AppStorys.shared
        private let position: String
        
        public init(position: String) {
            self.position = position
        }
        
        public var body: some View {
            // Find widget campaign matching this position
            if let campaign = sdk.widgetCampaigns.first(where: { $0.position == position }),
               case .widget(let widgetDetails) = campaign.details {
                WidgetView(
                    campaignId: campaign.id,
                    details: widgetDetails
                )
                .id(campaign.id)
            }
        }
    }
    
    // MARK: - All Widgets Container
    
    /// Display widget campaigns at specific positions
    ///
    /// **Position Discovery Flow:**
    /// 1. Tag positions in your app with `.captureAppStorysWidgetTag("position_name")`
    /// 2. Capture screen sends available positions to dashboard
    /// 3. Dashboard: Assign widget campaigns to specific positions
    /// 4. Backend sends campaigns with matching position
    /// 5. Widget displays at tagged location
    ///
    /// Usage:
    /// ```swift
    /// // Show all widgets (no filtering)
    /// AppStorys.Widgets()
    ///
    /// // Show widget at specific position (with position tagging for discovery)
    /// AppStorys.Widgets(position: "first_Widget")
    ///
    /// // Or tag separately for position discovery
    /// AppStorys.Widgets()
    ///     .captureAppStorysWidgetTag("first_Widget")
    /// ```
    struct Widgets: View {
        @ObservedObject private var sdk = AppStorys.shared
        private let position: String?
        
        /// Display all active widgets (no position filtering)
        public init() {
            self.position = nil
        }
        
        /// Display widget at a specific position with auto-tagging for dashboard discovery
        /// - Parameter position: Position identifier (will be sent to dashboard as "widget_<position>")
        public init(position: String) {
            self.position = position
        }
        
        public var body: some View {
            VStack(spacing: 0) {
                if let position = position {
                    // ✅ Show specific positioned widget with auto-tagging
                    filteredWidgetView(for: position)
                } else {
                    // ✅ Show all widgets (no filtering, no auto-tagging)
                    allWidgetsView
                }
            }
        }
        @ViewBuilder
        private func filteredWidgetView(for position: String) -> some View {
            let fullPosition = "widget_\(position)"
//            Logger.debug("🔍 Looking for widget at position: \(position) (full: \(fullPosition))")
//            Logger.debug("📋 Available campaigns: \(sdk.widgetCampaigns.map { "id=\($0.id), pos=\($0.position ?? "nil")" }.joined(separator: ", "))")
            
            // ✅ Only show widget that matches this position exactly
            if let campaign = sdk.widgetCampaigns.first(where: { campaign in
                guard let campaignPosition = campaign.position, !campaignPosition.isEmpty else {
                    Logger.debug("❌ Skipping campaign \(campaign.id) - position is nil or empty")
                    return false
                }
                let matches = campaignPosition == fullPosition || campaignPosition == position
                Logger.debug("\(matches ? "✅" : "❌") Campaign \(campaign.id) position '\(campaignPosition)' \(matches ? "matches" : "doesn't match") '\(position)'")
                return matches
            }), case .widget(let widgetDetails) = campaign.details {
//                Logger.debug("✅ Rendering widget campaign: \(campaign.id) at position: \(position)")
                WidgetView(
                    campaignId: campaign.id,
                    details: widgetDetails
                )
                .id(campaign.id)
            } else {
//                Logger.debug("⚠️ No matching widget found for position: \(position)")
                EmptyView()
            }
        }
        
        @ViewBuilder
        private var allWidgetsView: some View {
            // ✅ Filter to only campaigns with nil or empty position (fallback widgets)
            let defaultWidgets = sdk.widgetCampaigns.filter { campaign in
                if let position = campaign.position, !position.isEmpty {
                    Logger.debug("⏭ Skipping widget \(campaign.id) in default-widgets view (position=\(position))")
                    return false
                } else {
                    Logger.debug("✅ Including default widget \(campaign.id) (position is nil or empty)")
                    return true
                }
            }
            
            // ✅ Pick only one fallback widget if multiple exist
            if let campaign = defaultWidgets.first {
//                Logger.debug("🎯 Rendering single fallback widget: \(campaign.id)")
                
                if case .widget(let widgetDetails) = campaign.details {
                    WidgetView(
                        campaignId: campaign.id,
                        details: widgetDetails
                    )
                    .id(campaign.id)
                } else {
//                    Logger.debug("⚠️ Fallback campaign \(campaign.id) has no widget details")
                    EmptyView()
                }
            } else {
//                Logger.debug("⚠️ No default (position=nil) widgets available")
                EmptyView()
            }
        }

    }
}
