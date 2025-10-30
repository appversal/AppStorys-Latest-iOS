////
////  StoriesView.swift
////  AppStorys_iOS
////
////  Created by Ansh Kalra on 30/10/25.
////
//
//
////
////  SDKViewExtensions.swift
////  AppStorys_iOS
////
////  Clean API for accessing story and widget views
////
//
//import SwiftUI
//
//// MARK: - SDK View Extensions
//
//extension AppStorysSDK {
//    
//    // MARK: - Stories View Property
//    
//    /// Returns a ready-to-use story thumbnails view if stories are available
//    @ViewBuilder
//    public var stories: some View {
//        if !storyCampaigns.isEmpty {
//            StoryGroupThumbnailView(
//                manager: storyManager,
//                campaigns: storyCampaigns
//            ) { campaign, groupIndex in
//                self.presentStory(campaign: campaign, initialGroupIndex: groupIndex)
//            }
//        }
//    }
//    
//    // MARK: - Widgets View Property
//    
//    /// Returns a ready-to-use widget view if an active widget campaign exists
//    @ViewBuilder
//    public var widgets: some View {
//        if let widgetCampaign = activeWidgetCampaign,
//           case let .widget(widgetDetails) = widgetCampaign.details {
//            WidgetView(
//                campaignId: widgetCampaign.id,
//                details: widgetDetails
//            )
//        }
//    }
//    
//    // MARK: - Convenience Properties
//    
//    /// Check if stories are available
//    public var hasStories: Bool {
//        !storyCampaigns.isEmpty
//    }
//    
//    /// Check if widgets are available
//    public var hasWidgets: Bool {
//        if let campaign = activeWidgetCampaign,
//           case .widget(_) = campaign.details {
//            return true
//        }
//        return false
//    }
//    
//    // MARK: - Combined Content View
//    
//    /// Returns both stories and widgets in a vertical stack
//    @ViewBuilder
//    public var content: some View {
//        VStack(spacing: 16) {
//            stories
//            widgets
//        }
//    }
//}
//
//// MARK: - Alternative Implementation with Wrapped Views
//
///// A wrapper view that provides more control over stories display
//public struct StoriesView: View {
//    @ObservedObject private var sdk: AppStorysSDK
//    
//    public init(sdk: AppStorysSDK) {
//        self.sdk = sdk
//    }
//    
//    public var body: some View {
//        if !sdk.storyCampaigns.isEmpty {
//            StoryGroupThumbnailView(
//                manager: sdk.storyManager,
//                campaigns: sdk.storyCampaigns
//            ) { campaign, groupIndex in
//                sdk.presentStory(campaign: campaign, initialGroupIndex: groupIndex)
//            }
//        }
//    }
//}
//
///// A wrapper view that provides more control over widgets display
//public struct WidgetsView: View {
//    @ObservedObject private var sdk: AppStorysSDK
//    
//    public init(sdk: AppStorysSDK) {
//        self.sdk = sdk
//    }
//    
//    public var body: some View {
//        if let widgetCampaign = sdk.activeWidgetCampaign,
//           case let .widget(widgetDetails) = widgetCampaign.details {
//            WidgetView(
//                campaignId: widgetCampaign.id,
//                details: widgetDetails
//            )
//        }
//    }
//}
//
//// MARK: - Builder Pattern for Advanced Customization
//
//extension AppStorysSDK {
//    
//    /// Builder for customized story view
//    public func storiesView() -> StoriesViewBuilder {
//        StoriesViewBuilder(sdk: self)
//    }
//    
//    /// Builder for customized widget view  
//    public func widgetsView() -> WidgetsViewBuilder {
//        WidgetsViewBuilder(sdk: self)
//    }
//}
//
///// Builder for customizable story views
//public struct StoriesViewBuilder {
//    private let sdk: AppStorysSDK
//    private var spacing: CGFloat = 8
//    private var padding: EdgeInsets = .init()
//    private var onTap: ((Campaign, Int) -> Void)?
//    
//    fileprivate init(sdk: AppStorysSDK) {
//        self.sdk = sdk
//    }
//    
//    public func spacing(_ value: CGFloat) -> StoriesViewBuilder {
//        var builder = self
//        builder.spacing = value
//        return builder
//    }
//    
//    public func padding(_ insets: EdgeInsets) -> StoriesViewBuilder {
//        var builder = self
//        builder.padding = insets
//        return builder
//    }
//    
//    public func onTap(_ handler: @escaping (Campaign, Int) -> Void) -> StoriesViewBuilder {
//        var builder = self
//        builder.onTap = handler
//        return builder
//    }
//    
//    @ViewBuilder
//    public func build() -> some View {
//        if !sdk.storyCampaigns.isEmpty {
//            StoryGroupThumbnailView(
//                manager: sdk.storyManager,
//                campaigns: sdk.storyCampaigns
//            ) { campaign, groupIndex in
//                if let onTap = onTap {
//                    onTap(campaign, groupIndex)
//                } else {
//                    sdk.presentStory(campaign: campaign, initialGroupIndex: groupIndex)
//                }
//            }
//            .padding(padding)
//        }
//    }
//}
//
///// Builder for customizable widget views
//public struct WidgetsViewBuilder {
//    private let sdk: AppStorysSDK
//    private var padding: EdgeInsets = .init()
//    private var onTap: ((WidgetImage) -> Void)?
//    
//    fileprivate init(sdk: AppStorysSDK) {
//        self.sdk = sdk
//    }
//    
//    public func padding(_ insets: EdgeInsets) -> WidgetsViewBuilder {
//        var builder = self
//        builder.padding = insets
//        return builder
//    }
//    
//    public func onTap(_ handler: @escaping (WidgetImage) -> Void) -> WidgetsViewBuilder {
//        var builder = self
//        builder.onTap = handler
//        return builder
//    }
//    
//    @ViewBuilder
//    public func build() -> some View {
//        if let widgetCampaign = sdk.activeWidgetCampaign,
//           case let .widget(widgetDetails) = widgetCampaign.details {
//            WidgetView(
//                campaignId: widgetCampaign.id,
//                details: widgetDetails
//            )
//            .padding(padding)
//        }
//    }
//}
//
//// MARK: - View Modifiers for Conditional Display
//
//public extension View {
//    
//    /// Conditionally show this view only if stories are available
//    func showIfStoriesAvailable(_ sdk: AppStorysSDK) -> some View {
//        opacity(sdk.hasStories ? 1 : 0)
//        .frame(height: sdk.hasStories ? nil : 0)
//    }
//    
//    /// Conditionally show this view only if widgets are available
//    func showIfWidgetsAvailable(_ sdk: AppStorysSDK) -> some View {
//        opacity(sdk.hasWidgets ? 1 : 0)
//        .frame(height: sdk.hasWidgets ? nil : 0)
//    }
//}
