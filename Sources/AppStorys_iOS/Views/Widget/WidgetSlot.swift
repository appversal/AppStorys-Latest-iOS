//
//  WidgetSlot.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//

import SwiftUI

public extension AppStorys {
    /// Public widget container that automatically displays all active widget campaigns.
    struct Widgets: View {
        // MARK: - Dependencies
        @ObservedObject private var sdk = AppStorys.shared

        // MARK: - Init
        /// Public initializer for easy integration (no parameters needed)
        public init() {}

        // MARK: - Body
        public var body: some View {
            VStack(spacing: 0) {
                ForEach(sdk.widgetCampaigns) { campaign in
                    if case .widget(let widgetDetails) = campaign.details {
                        WidgetView(
                            campaignId: campaign.id,
                            details: widgetDetails
                        )
                        .id(campaign.id)
                    }
                }
            }
        }
    }
}
