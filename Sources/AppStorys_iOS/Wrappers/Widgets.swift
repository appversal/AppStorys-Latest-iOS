////
////  Widgets.swift
////  AppStorys_iOS
////
////  Created by Ansh Kalra on 03/11/25.
////
//
//import SwiftUI
//
//public extension AppStorys {
//    /// Public-facing Widgets view — displays all widget campaigns
//    struct Widgets: View {
//        @ObservedObject private var sdk = AppStorys.shared
//
//        public init() {}
//
//        public var body: some View {
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 12) {
//                    ForEach(sdk.widgetCampaigns) { campaign in
//                        if case .widget(let widgetDetails) = campaign.details {
//                            WidgetView(
//                                campaignId: campaign.id,
//                                details: widgetDetails
//                            )
//                            .id(campaign.id)
//                        }
//                    }
//                }
//            }
//            .onAppear {
//                print("🧩 AppStorys.Widgets appeared")
//                print("🧩 Widget campaigns count: \(sdk.widgetCampaigns.count)")
//                sdk.widgetCampaigns.forEach { print("🧩 Widget: \($0.id), type: \($0.details)") }
//            }
//        }
//    }
//}
