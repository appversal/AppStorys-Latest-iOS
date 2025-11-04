////
////  MyView.swift
////  AppStorys_iOS
////
////  Created by Ansh Kalra on 04/11/25.
////
//
//
////
////  PublicAPIWrappers.swift
////  AppStorys_iOS
////
////  ✅ COMPREHENSIVE: All public SDK methods with auto-initialization
////  ✅ DEVELOPER-FRIENDLY: No initialization checks needed
////
//
//import SwiftUI
//
//// MARK: - User Attributes
//public extension AppStorys {
//    
//    /// Set user attributes
//    /// ✅ Automatically waits for SDK to be ready
//    ///
//    /// Example:
//    /// ```swift
//    /// AppStorys.setUserAttributes([
//    ///     "name": "John Doe",
//    ///     "email": "john@example.com",
//    ///     "premium": true
//    /// ])
//    /// ```
//    static func setUserAttributes(_ attributes: [String: Any]) {
//        Task {
//            await shared.waitForInitialization()
//            
//            await MainActor.run {
//                shared.setUserAttributes(attributes)
//            }
//        }
//    }
//}
//
//// MARK: - Campaign Control
//public extension AppStorys {
//    
//    /// Hide all active campaigns
//    /// ✅ Automatically waits for SDK to be ready
//    ///
//    /// Example:
//    /// ```swift
//    /// Button("Hide Campaigns") {
//    ///     AppStorys.hideAllCampaigns()
//    /// }
//    /// ```
//    static func hideAllCampaigns() {
//        Task {
//            await shared.waitForInitialization()
//            
//            await MainActor.run {
//                shared.hideAllCampaigns()
//            }
//        }
//    }
//    
//    /// Dismiss a specific campaign
//    /// ✅ Automatically waits for SDK to be ready
//    ///
//    /// Example:
//    /// ```swift
//    /// AppStorys.dismissCampaign("campaign_123")
//    /// ```
//    static func dismissCampaign(_ campaignId: String) {
//        Task {
//            await shared.waitForInitialization()
//            
//            await MainActor.run {
//                shared.dismissCampaign(campaignId)
//            }
//        }
//    }
//    
//    /// Check if a campaign is dismissed
//    /// ✅ Automatically waits for SDK to be ready
//    static func isCampaignDismissed(_ campaignId: String) async -> Bool {
//        await shared.waitForInitialization()
//        return await MainActor.run {
//            shared.isCampaignDismissed(campaignId)
//        }
//    }
//}
//
//// MARK: - Story Control
//public extension AppStorys {
//    
//    /// Present a story campaign
//    /// ✅ Automatically waits for SDK to be ready
//    ///
//    /// Example:
//    /// ```swift
//    /// if let storyCampaign = AppStorys.shared.storyCampaigns.first {
//    ///     AppStorys.presentStory(campaign: storyCampaign)
//    /// }
//    /// ```
//    static func presentStory(campaign: StoryCampaign, initialGroupIndex: Int = 0) {
//        Task {
//            await shared.waitForInitialization()
//            
//            await MainActor.run {
//                shared.presentStory(campaign: campaign, initialGroupIndex: initialGroupIndex)
//            }
//        }
//    }
//    
//    /// Dismiss the currently presented story
//    /// ✅ Automatically waits for SDK to be ready
//    static func dismissStory() {
//        Task {
//            await shared.waitForInitialization()
//            
//            await MainActor.run {
//                shared.dismissStory()
//            }
//        }
//    }
//}
//
//// MARK: - Screen Capture
//public extension AppStorys {
//    
//    /// Capture the current screen
//    /// ✅ Automatically waits for SDK to be ready
//    /// ⚠️ Only works if screen capture is enabled on the server
//    ///
//    /// Example:
//    /// ```swift
//    /// struct MyView: View {
//    ///     var body: some View {
//    ///         VStack {
//    ///             Button("Capture") {
//    ///                 AppStorys.captureScreen()
//    ///             }
//    ///         }
//    ///     }
//    /// }
//    /// ```
//    static func captureScreen() async throws {
//        await shared.waitForInitialization()
//        
//        guard let rootView = try? getCaptureView() else {
//            throw ScreenCaptureError.noActiveScreen
//        }
//        
//        try await shared.captureScreen(from: rootView)
//    }
//    
//    /// Check if screen capture is enabled
//    static func isScreenCaptureEnabled() async -> Bool {
//        await shared.waitForInitialization()
//        return await MainActor.run {
//            shared.isScreenCaptureEnabled
//        }
//    }
//}
//
//// MARK: - SDK State
//public extension AppStorys {
//    
//    /// Check if SDK is initialized
//    /// ✅ Can be called anytime
//    static var isInitialized: Bool {
//        shared.isInitialized
//    }
//    
//    /// Get debug information about SDK state
//    /// ✅ Useful for troubleshooting
//    static var debugInfo: String {
//        shared.debugInfo
//    }
//    
//    /// Print debug information to console
//    static func printDebugInfo() {
//        shared.printDebugInfo()
//    }
//}
//
//// MARK: - Cleanup
//public extension AppStorys {
//    
//    /// Reset SDK to initial state
//    /// ⚠️ Use with caution - clears all campaign state
//    static func reset() {
//        Task {
//            await MainActor.run {
//                shared.reset()
//            }
//        }
//    }
//    
//    /// Shutdown SDK completely
//    /// ⚠️ Call before app termination if needed
//    static func shutdown() async {
//        await shared.shutdownAsync()
//    }
//}
//
//// MARK: - Helper to get root view for screen capture
//private func getCaptureView() throws -> UIView {
//    guard let windowScene = UIApplication.shared.connectedScenes
//        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
//          let window = windowScene.windows.first(where: { $0.isKeyWindow }),
//          let rootView = window.rootViewController?.view else {
//        throw ScreenCaptureError.noActiveScreen
//    }
//    return rootView
//}
