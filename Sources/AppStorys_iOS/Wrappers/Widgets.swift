//
//  Widgets.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//

import SwiftUI

public extension AppStorys {
    /// Public-facing Widgets view — displays all widget campaigns
    struct Widgets: View {
        @ObservedObject private var sdk = AppStorys.shared

        public init() {}

        public var body: some View {
            WidgetSlotViewWrapper(sdk: sdk)
        }
    }
}

/// Internal wrapper to isolate logic
private struct WidgetSlotViewWrapper: View {
    @ObservedObject var sdk: AppStorys

    var body: some View {
        // Example structure — replace with your real widget slot logic
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(sdk.widgetCampaigns) { campaign in
                    WidgetSlot()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
