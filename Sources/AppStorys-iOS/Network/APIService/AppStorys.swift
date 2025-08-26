//
//  File.swift
//  AppStorys-iOS-main-3
//
//  Created by Darshika Gupta on 28/02/25.
//

import SwiftUI
import Foundation
import Combine
import UIKit

public class DeepLinkManager {
    @MainActor public static let shared = DeepLinkManager()
    public var navigateToScreen: ((String, [String: String]?) -> Void)?
}

@MainActor
public class AppStorys: ObservableObject {
    private var floaterWindow: UIWindow?
    var pipFullScreenWindow: UIWindow?
    private var bottomSheetWindow: UIWindow?
    @State var isShowing = true
    var csatWindow: UIWindow?
    var surveyWindow: UIWindow?
    private var pipWindow: UIWindow?
    private let session: URLSession
    var testSession: URLSession {
        return session
    }
    var bannerWindow: UIWindow?
    private var modalWindow: UIWindow?
    var pendingBottomSheets: [CampaignModel] = []
    var pendingModals: [CampaignModel] = []
    var pendingTooltips: [CampaignModel] = []
    var pendingSurveys: [CampaignModel] = []
    var pendingPips: [CampaignModel] = []
    var pendingCsat: [CampaignModel] = []
    var pendingBanner: [CampaignModel] = []
    var pendingFloater: [CampaignModel] = []
    @Published var accessToken: String? = nil
    @Published var widgetCampaigns: [CampaignModel] = []
    @Published var banCampaigns: [CampaignModel] = []
    @Published var csatCampaigns: [CampaignModel] = []
    @Published var pipCampaigns: [CampaignModel] = []
    @Published var toolTipCampaigns: [CampaignModel] = []
    @Published var floaterCampaigns: [CampaignModel] = []
    
    func handleNewCampaignResponse(_ response: CampaignResponse, for screenName: String) {
        if response.metadata?.screenCaptureEnabled == true {
            UIAnalyzer.analyzeCurrentScreen(screenName: screenName)
        }
        print("📺 handleNewCampaignResponse CALLED for screen: [\(screenName)]")
        
        var normalizedTargetScreen = screenName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var normalizedCurrentScreen = currentScreen.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let deviceInfo = getDeviceInfo()
        let mergedAttributes = (attributes ?? [:]).merging(deviceInfo) { $1 }
        if normalizedTargetScreen != normalizedCurrentScreen {
            print("⚠️ Ignoring campaign response for [\(normalizedTargetScreen)] as currentScreen is [\(normalizedCurrentScreen)]")
            print("🔁 Retrying for current screen...")
            
            Task {
                let (response, websocketResponse) = await triggerScreenData(
                    accessToken: accessToken!,
                    screenName: currentScreen,
                    userId: userId,
                    attributes: mergedAttributes
                ) ?? (nil, nil)
                print(accessToken)
                if let response {
                    handleNewCampaignResponse(response, for: currentScreen)
                    if let campaigns = response.campaigns {
                        _campaigns.send(campaigns)
                    }
                }
            }
            
            return
        }
        
        guard normalizedTargetScreen == normalizedCurrentScreen else {
            print("⚠️ Ignoring campaign response for [\(normalizedTargetScreen)] as currentScreen is [\(normalizedCurrentScreen)]")
            return
        }
        
        let tooltips = response.campaigns?.filter {
            if case .toolTip = $0.details,
               let screen = $0.screen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               screen == normalizedCurrentScreen {
                return true
            }
            return false
        } ?? []
        self.pendingTooltips = tooltips.filter {
            $0.displayTrigger == true && $0.triggerEvent != nil
        }
        let analyzer = UIAnalyzer()
        if !tooltips.isEmpty {
            let eligibleCampaigns = tooltips.filter { $0.displayTrigger == false }
            if !eligibleCampaigns.isEmpty {
                analyzer.showTooltipsSequentially(from: eligibleCampaigns)
            }
        }

        
        let floaters = response.campaigns?.filter {
            if case .floater = $0.details,
               let screen = $0.screen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               screen == normalizedCurrentScreen {
                return true
            }
            return false
        } ?? []
        
        self.pendingFloater = floaters.filter {
            $0.displayTrigger == true && $0.triggerEvent != nil
        }
        
        let banners = response.campaigns?.filter {
            if case .banner = $0.details,
               let screen = $0.screen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               screen == normalizedCurrentScreen {
                return true
            }
            return false
        } ?? []
        self.pendingBanner = banners.filter {
            $0.displayTrigger == true && $0.triggerEvent != nil
        }
        
        let widgets = response.campaigns?.filter {
            if case .widget = $0.details,
               let screen = $0.screen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               screen == normalizedCurrentScreen {
                return true
            }
            return false
        } ?? []
        
        let csats = response.campaigns?.filter {
            if case .csat = $0.details,
               let screen = $0.screen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               screen == normalizedCurrentScreen {
                return true
            }
            return false
        } ?? []
        self.pendingCsat = csats.filter {
            $0.displayTrigger == true && $0.triggerEvent != nil
        }
        
        let pips = response.campaigns?.filter {
            if case .pip = $0.details,
               let screen = $0.screen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               screen == normalizedCurrentScreen {
                return true
            }
            return false
        } ?? []
        self.pendingPips = pips.filter {
            $0.displayTrigger == true && $0.triggerEvent != nil
        }
        
        let surveys = response.campaigns?.filter {
            if case .survey = $0.details,
               let screen = $0.screen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               screen == normalizedCurrentScreen {
                return true
            }
            return false
        } ?? []
        self.pendingSurveys = surveys.filter {
            $0.displayTrigger == true && $0.triggerEvent != nil
        }
        
        let stories = response.campaigns?.filter {
            if case .stories = $0.details,
               let screen = $0.screen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               screen == normalizedCurrentScreen {
                return true
            }
            return false
        } ?? []
        
        let reels = response.campaigns?.filter {
            if case .reel = $0.details,
               let screen = $0.screen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               screen == normalizedCurrentScreen {
                return true
            }
            return false
        } ?? []
        
        let bottomSheets = response.campaigns?.filter {
            if case .bottomSheets = $0.details,
               let screen = $0.screen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               screen == normalizedCurrentScreen {
                return true
            }
            return false
        } ?? []
        self.pendingBottomSheets = bottomSheets.filter {
            $0.displayTrigger == true && $0.triggerEvent != nil
        }
        
        let modals = response.campaigns?.filter {
            if case .modals = $0.details,
               let screen = $0.screen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               screen == normalizedCurrentScreen {
                return true
            }
            return false
        } ?? []
        self.pendingModals = modals.filter {
            $0.displayTrigger == true && $0.triggerEvent != nil
        }
        DispatchQueue.main.async {
            self.floaterCampaigns = floaters
            self.banCampaigns = banners
            self.widgetCampaigns = widgets
            self.csatCampaigns = csats
            self.pipCampaigns = pips
            self.surveyCampaigns = surveys
            self.storiesCampaigns = stories
            self.reelsCampaigns = reels
            self.bottomSheetsCampaigns = bottomSheets
            self.modalsCampaigns = modals
            self.toolTipCampaigns = tooltips
            if let campaign = floaters.first,
               campaign.displayTrigger == false {
                self.showFloaterOverlay(for: campaign)
            } else {
                self.hideFloaterOverlay()
            }
            if let campaign = bottomSheets.first,
                campaign.displayTrigger == false {
                self.showBottomSheetOverlay(for: campaign)
            } else {
                self.hideBottomSheetOverlay()
            }
            if let campaign = banners.first ,
                campaign.displayTrigger == false {
                self.showBannerOverlay(for: campaign)
            } else {
                self.hideBannerOverlay()
            }
            if let campaign = csats.first ,
                campaign.displayTrigger == false {
                self.showCsatOverlay(for: campaign)
            } else {
                self.hideCsatOverlay()
            }
            print("dff : \(pips.first?.displayTrigger)")
            if let campaign = pips.first ,
                campaign.displayTrigger == false {
                self.showPipOverlay(for: campaign)
            } else {
                self.hidePipOverlay()
            }
            
            if let campaign = surveys.first ,
                campaign.displayTrigger == false {
                self.showSurveyOverlay(for: campaign)
            } else {
                self.hideSurveyOverlay()
            }
            if let campaign = modals.first ,
                campaign.displayTrigger == false {
                self.showModalOverlay(for: campaign)
            } else {
                self.hideModalOverlay()
            }
            }
        }
    

    @Published var surveyCampaigns: [CampaignModel] = []
    @Published var storiesCampaigns: [CampaignModel] = []
    @Published var reelsCampaigns: [CampaignModel] = []
    @Published var bottomSheetsCampaigns: [CampaignModel] = []
    @Published var modalsCampaigns: [CampaignModel] = []

    var hasShownFloater = false
    var hasShownSurvey = false
    var hasShownPip = false
    var hasShownCsat = false
    var hasShownModal = false

    private var webSocketConfig: WebSocketConfig?
    @Published var isScreenCaptureEnabled: Bool = false
    private let _campaigns = CurrentValueSubject<[CampaignModel], Never>([])
    private let _disabledCampaigns = CurrentValueSubject<[String], Never>([])
    private let _impressions = CurrentValueSubject<[String], Never>([])
    private var webSocketClient = WebSocketClient()
    var campaigns: AnyPublisher<[CampaignModel], Never> {
        return _campaigns.eraseToAnyPublisher()
    }
    var disabledCampaigns: AnyPublisher<[String], Never> {
        return _disabledCampaigns.eraseToAnyPublisher()
    }
    var impressions: AnyPublisher<[String], Never> {
        return _impressions.eraseToAnyPublisher()
    }
    var currentScreen: String = ""
    var userId: String = ""
    var attributes: [String: Any]? = nil
    
    
    public init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }
    
    public enum Endpoints: String {
        case validateAccount = "/validate-account/"
        case trackScreen = "/track-screen/"
        case trackUser = "/track-user/"
        case trackAction = "/track-action/"
    }
    
    public func appstorys(appID: String, accountID: String, userID: String) async {
        KeychainHelper.shared.save(userID, key: "userIDAppStorys")
        await validateAccount(appID: appID, accountID: accountID)
        
        if let accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys") {
                print("Access Token: \(accessToken)")
            } else {
                print("Access Token not found")
            }
    }
    
    public func validateAccount(appID: String, accountID: String) async {
        let url = URL(string: "https://backend.appstorys.com/api/v1/users\(Endpoints.validateAccount.rawValue)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "app_id": appID,
            "account_id": accountID
        ]
        request.httpBody = try? JSONEncoder().encode(body)
        do {
            let (data, _) = try await session.data(for: request)
            let decodedResponse = try JSONDecoder().decode(ValidateAccountResponse.self, from: data)
            
            DispatchQueue.main.async {
                self.accessToken = decodedResponse.access_token
                KeychainHelper.shared.save(decodedResponse.access_token, key: "accessTokenAppStorys")
                KeychainHelper.shared.save(decodedResponse.refresh_token, key: "refreshTokenAppStorys")
            }
        } catch {
        }
    }

    public func getScreenCampaigns(screenName: String, positionList: [String]) async {
        print("👉 [getScreenCampaigns] Started for screen: \(screenName), positions: \(positionList)")

        accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys") ?? ""
        userId = KeychainHelper.shared.get(key: "userIDAppStorys") ?? ""

        print("🔑 AccessToken fetched: \(accessToken?.isEmpty == false ? "Available" : "Missing")")
        print("👤 UserID fetched: \(userId.isEmpty ? "Missing" : userId)")

        guard !accessToken!.isEmpty, !userId.isEmpty else {
            print("❌ Missing accessToken or userId → Cannot proceed")
            return
        }

        let deviceInfo = getDeviceInfo()
        print("📱 Device Info: \(deviceInfo)")

        let mergedAttributes = (attributes ?? [:]).merging(deviceInfo) { $1 }
        print("🛠️ Merged Attributes: \(mergedAttributes)")

        currentScreen = screenName
        print("📺 Current Screen set: \(currentScreen ?? "nil")")

        print("🚀 Triggering screen data API...")
        let (campaignResponse, webSocketResponse) = await triggerScreenData(
            accessToken: accessToken!,
            screenName: screenName,
            userId: userId,
            attributes: mergedAttributes
        ) ?? (nil, nil)

        if let response = campaignResponse {
            print("✅ Campaign Response received with \(response.campaigns?.count ?? 0) campaigns")
            
//            isScreenCaptureEnabled = webSocketResponse?.ws.screen_capture_enabled ?? false
            print("📡 WebSocket screen capture enabled: \(isScreenCaptureEnabled)")

            if let campaigns = response.campaigns {
                print("📊 Campaigns Data: \(campaigns)")
                _campaigns.send(campaigns)
                print("📤 Campaigns published successfully")
            } else {
                print("⚠️ No campaigns found in response")
            }
        } else {
            print("❌ No campaign response received")
        }

        print("🏁 [getScreenCampaigns] Finished")
    }

    func getDeviceInfo() -> [String: Any] {
        let device = UIDevice.current
        let screen = UIScreen.main
        let locale = Locale.current
        let timeZone = TimeZone.current
        let orientation = UIDevice.current.orientation
        let appInfo = Bundle.main

        let screenBounds = screen.bounds
        let screenWidth = Int(screenBounds.width * screen.scale)
        let screenHeight = Int(screenBounds.height * screen.scale)
        let density = Int(screen.scale * 160)

        let installTime: Int64 = {
            if let documentsFolder = try? FileManager.default.attributesOfItem(atPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!) {
                if let creationDate = documentsFolder[.creationDate] as? Date {
                    return Int64(creationDate.timeIntervalSince1970 * 1000)
                }
            }
            return 0
        }()

        let updateTime: Int64 = {
            if let infoPath = Bundle.main.path(forResource: "Info", ofType: "plist"),
               let attrs = try? FileManager.default.attributesOfItem(atPath: infoPath),
               let modDate = attrs[.modificationDate] as? Date {
                return Int64(modDate.timeIntervalSince1970 * 1000)
            }
            return 0
        }()

        return [
            "manufacturer": "Apple",
            "model": device.model,
            "os_version": device.systemVersion,
            "api_level": UIDevice.current.systemVersion,
            "language": locale.languageCode ?? "",
            "locale": locale.identifier,
            "timezone": timeZone.identifier,
            "screen_width_px": screenWidth,
            "screen_height_px": screenHeight,
            "screen_density": density,
            "orientation": (orientation.isPortrait || orientation == .unknown) ? "portrait" : "landscape",
            "app_version": appInfo.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            "package_name": Bundle.main.bundleIdentifier ?? "",
            "install_time": installTime,
            "update_time": updateTime,
            "device_type": "mobile",
            "platform": "ios"
        ]
    }

    private var campaignResponseQueue: [CampaignResponse] = []
    
    @MainActor
    func triggerScreenData(
        accessToken: String?,
        screenName: String,
        userId: String,
        attributes: [String: Any]?,
        timeoutMs: Int = 60_000
    ) async -> (CampaignResponse?, WebSocketConnectionResponse?) {
        
        print("🚀 triggerScreenData started")
        
        guard let token = accessToken, !token.isEmpty else {
            print("❌ Access token is missing")
            return (nil, nil)
        }
        
        // Call API to get WebSocket details
        let request = TrackUserWebSocketRequest(
            user_id: userId,
            attributes: attributes?.mapValues { AnyCodable($0) } ?? [:],
            screenName: screenName,
            silentUpdate: nil
        )
        
        var webSocketResponse: WebSocketConnectionResponse
        do {
            webSocketResponse = try await getWebSocketConnectionDetails(token: "Bearer \(token)", request: request)
            print("✅ Received WebSocket response: \(webSocketResponse.ws)")
        } catch {
            print("❌ Error fetching WebSocket details: \(error)")
            return (nil, nil)
        }

        // Connect directly using URL and token from API response
        print("🌐 [WebSocket] Connecting to: \(webSocketResponse.ws)")
        webSocketClient.connect(with: webSocketResponse.ws)

        // Listen for campaign response
        print("👂 [WebSocket] Listening for campaign response (Timeout: \(timeoutMs) ms)")
        let campaignResponse = await withTimeout(milliseconds: timeoutMs) {
            await withCheckedContinuation { continuation in
                self.webSocketClient.onCampaignResponse = { response in
                    print("📩 [WebSocket] Campaign response received: \(response)")
                    
                    Task { @MainActor in
                        continuation.resume(returning: response)
                        print("🔄 [WebSocket] Continuation resumed with campaign response")
                        
                        // Avoid memory leaks by clearing the handler
                        self.webSocketClient.onCampaignResponse = nil
                        print("🧹 [WebSocket] Cleared campaign response handler")
                    }
                }
            }
        }

        // Handle the response or timeout
        if let response = campaignResponse {
            print("✅ [WebSocket] Successfully received campaign response: \(response)")
            handleNewCampaignResponse(response, for: screenName)
            print("📦 [WebSocket] Passed response to handler for screen: \(screenName)")
        } else {
            print("⏱ [WebSocket] Timeout reached after \(timeoutMs) ms - No campaign response received")
        }

        return (campaignResponse, webSocketResponse)
    }


    func getWebSocketConnectionDetails(token: String,
                                       request: TrackUserWebSocketRequest) async throws -> WebSocketConnectionResponse {
        print("🚀 Starting getWebSocketConnectionDetails")

        guard let url = URL(string: "https://users.appstorys.com/track-user") else {
            print("❌ Invalid URL")
            throw URLError(.badURL)
        }
        print("🌐 URL: \(url.absoluteString)")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("\(token)", forHTTPHeaderField: "Authorization")
        print("📝 Request Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")

        // Encode request body
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            urlRequest.httpBody = try encoder.encode(request)
            if let bodyString = String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) {
                print("📦 Request Body: \n\(bodyString)")
            }
        } catch {
            print("❌ Failed to encode request body: \(error.localizedDescription)")
            throw error
        }

        // Perform API call
        print("📡 Sending request...")
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        print("✅ Response received")

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Response is not HTTPURLResponse")
            throw URLError(.badServerResponse)
        }
        print("📊 Status Code: \(httpResponse.statusCode)")
        if !(200...299).contains(httpResponse.statusCode) {
            print("⚠️ Unexpected status code: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }

        // Decode JSON response
        let decoder = JSONDecoder()
        do {
            let webSocketResponse = try decoder.decode(WebSocketConnectionResponse.self, from: data)
            print("🎯 Decoded Response: \(webSocketResponse)")
            return webSocketResponse
        } catch {
            if let rawString = String(data: data, encoding: .utf8) {
                print("❌ Failed to decode response. Raw response:\n\(rawString)")
            }
            throw error
        }
    }

        // MARK: - Helper
        
    func waitForCampaignResponse() async -> CampaignResponse? {
        print("⏳ Waiting for campaign response...")
        
        let response = await withCheckedContinuation { continuation in
            print("🔧 Setting WebSocket onCampaignResponse handler...")
            
            self.webSocketClient.onCampaignResponse = { response in
                print("📩 Campaign response received from WebSocket: \(response)")
                
                Task { @MainActor in
                    print("⚡ Resuming continuation with campaign response...")
                    continuation.resume(returning: response)
                    
                    print("🧹 Clearing onCampaignResponse handler...")
                    self.webSocketClient.onCampaignResponse = nil
                }
            }
        }
        
        print("✅ waitForCampaignResponse completed with response: \(String(describing: response))")
        return response
    }



       
    private func withTimeout<T: Sendable>(
        milliseconds: Int,
        operation: @MainActor @escaping () async -> T
    ) async -> T? {
        let timeout = UInt64(milliseconds) * 1_000_000
        print("⏱ [withTimeout] Started with \(milliseconds) ms timeout")

        return await withTaskGroup(of: T?.self) { group in
            // Operation task
            group.addTask {
                print("▶️ [withTimeout] Operation task started")
                let result = await operation()
                print("✅ [withTimeout] Operation task completed with result: \(result)")
                return result
            }

            // Timeout task
            group.addTask {
                do {
                    print("⏳ [withTimeout] Timeout task sleeping for \(milliseconds) ms")
                    try await Task.sleep(nanoseconds: timeout)
                    print("⏰ [withTimeout] Timeout expired after \(milliseconds) ms")
                } catch {
                    print("🛑 [withTimeout] Timeout task cancelled")
                }
                return nil
            }

            // Wait for the first completed task
            let result = await group.next() ?? nil

            // Cancel remaining tasks to prevent logs firing later
            group.cancelAll()

            if result == nil {
                print("🚨 [withTimeout] Returning nil (timeout hit)")
            } else {
                print("🏁 [withTimeout] Returning operation result: \(String(describing: result))")
            }

            return result
        }
    }



    struct SendableBox<T>: @unchecked Sendable {
        let value: T?
    }



    
    func clickEvent(link: LinkType?, campaignId: String, widgetImageId: String? = nil) {
        guard let link = link else {
            return
        }
        switch link {
        case .string(let url):
            if isValidUrl(url) {
                openUrl(url)
            } else if let navigate = DeepLinkManager.shared.navigateToScreen {
                navigate(url, nil)
            } else {
            }
        case .dictionary(let deepLinkData):
            handleDeepLink(data: deepLinkData, campaignId: campaignId, widgetImageId: widgetImageId)
        case .none:
            return
        }
    }
    
    func handleDeepLink(data: LinkType.DeepLinkData, campaignId: String, widgetImageId: String?) {
        if let navigate = DeepLinkManager.shared.navigateToScreen {
            navigate(data.value, data.context)
        } else {
        }
    }
    func isValidUrl(_ url: String?) -> Bool {
        guard let urlString = url, let url = URL(string: urlString) else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }
    
    func openUrl(_ url: String) {
        guard let url = URL(string: url) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    public func trackEvents(eventType: String, campaignId: String? = nil, metadata: [String: Any]? = nil) {
        guard let accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys") else {
            print("Access token not found")
            return
        }
        guard let userID = KeychainHelper.shared.get(key: "userIDAppStorys") else {
            print("User ID not found")
            return
        }

        var requestBody: [String: Any] = [
            "user_id": userID,
            "event": eventType
        ]

        if let campaignId = campaignId {
            requestBody["campaign_id"] = campaignId
        }

        // Add device info
        let deviceInfo: [String: Any] = [
            "device_model": UIDevice.current.model,
            "device_name": UIDevice.current.name,
            "system_name": UIDevice.current.systemName,
            "system_version": UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "app_build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ]

        // Merge metadata with device info
        var mergedMetadata = deviceInfo
        if let metadata = metadata {
            for (key, value) in metadata {
                mergedMetadata[key] = value
            }
        }

        requestBody["metadata"] = mergedMetadata

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])

            var request = URLRequest(url: URL(string: "https://tracking.appstorys.com/capture-event")!)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error occurred: \(error.localizedDescription)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("Status Code: \(httpResponse.statusCode)")
                    print("Headers: \(httpResponse.allHeaderFields)")
                }

                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response Body: \(responseString)")
                    
                    let ignoredEvents = ["viewed", "clicked"]
                    guard !ignoredEvents.contains(eventType.lowercased()) else { return }
                    
                    DispatchQueue.main.async {
                        self.checkAndShowOverlay(
                            for: eventType,
                            campaigns: self.pendingBottomSheets,
                            show: { self.showBottomSheetOverlay(for: $0) },
                            hide: { self.hideBottomSheetOverlay() }
                        )
                        self.checkAndShowOverlay(
                            for: eventType,
                            campaigns: self.pendingPips,
                            show: { self.showPipOverlay(for: $0) },
                            hide: { self.hidePipOverlay() }
                        )
                        self.checkAndShowOverlay(
                            for: eventType,
                            campaigns: self.pendingFloater,
                            show: { self.showFloaterOverlay(for: $0) },
                            hide: { self.hideFloaterOverlay() }
                        )
                        self.checkAndShowOverlay(
                            for: eventType,
                            campaigns: self.pendingBanner,
                            show: { self.showBannerOverlay(for: $0) },
                            hide: { self.hideBannerOverlay() }
                        )
                        self.checkAndShowOverlay(
                            for: eventType,
                            campaigns: self.pendingCsat,
                            show: { self.showCsatOverlay(for: $0) },
                            hide: { self.hideCsatOverlay() }
                        )
                        self.checkAndShowOverlay(
                            for: eventType,
                            campaigns: self.pendingSurveys,
                            show: { self.showSurveyOverlay(for: $0) },
                            hide: { self.hideSurveyOverlay() }
                        )
                        self.checkAndShowOverlay(
                            for: eventType,
                            campaigns: self.pendingModals,
                            show: { self.showModalOverlay(for: $0) },
                            hide: { self.hideModalOverlay() }
                        )
                    }
                }
            }
            task.resume()
        } catch {
            print("JSON Serialization error: \(error.localizedDescription)")
        }
    }

    public func setUserProperties(attributes: [String: Any]) {
        guard let userID = KeychainHelper.shared.get(key: "userIDAppStorys"),
                      let accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys") else {
                    return
                }
        userId = KeychainHelper.shared.get(key: "userIDAppStorys") ?? ""
        let urlString = "https://users.appstorys.com/track-user"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "user_id": userId,
            "attributes": attributes,
            "silentUpdate": true
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            print("AppStorys: Error serializing request body - \(error)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("AppStorys: Error updating user properties - \(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("AppStorys: Invalid response")
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                print("AppStorys: User properties updated successfully")
            } else {
                let message = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                print("AppStorys: Error updating user properties - \(message)")
            }
        }

        task.resume()
    }

    
    func checkAndShowOverlay(
        for eventType: String,
        campaigns: [CampaignModel],
        show: (CampaignModel) -> Void,
        hide: () -> Void
    ) {
        let normalizedEvent = eventType.lowercased()

        print("Checking overlay for event: \(normalizedEvent)")

        if let campaign = campaigns.first(where: {
            $0.triggerEvent?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == normalizedEvent
        }) {
            print("Found matching campaign: \(campaign.id ?? "unknown")")
            show(campaign)
        } else {
            print("No campaign matched. Hiding overlay.")
            hide()
        }
    }

    struct AnalyticsEvent: Codable {
        let StorySlide_id: String
        let AppUser_id: String
        let event_type: String
    }
    
    
    struct TrackUserRequest: Codable {
        let user_id: String
        let campaign_list: [String]
        let attributes: [[String: AnyCodable]]?
        
    }
    struct TrackActionRequest: Codable {
        let campaign_id: String
        let user_id: String
        let event_type: String
        let widget_id: String?
    }
    
    private struct TrackScreenRequest: Codable {
        let screen_name: String
        let position_list: [String]
    }
}


enum APIError: Error {
    case noAccessToken
    case invalidResponse
    case invalidURL
}

enum ActionType: String {
    case view = "viewed"
    case click = "clicked"
}

struct TrackUserResponseTwo: Codable {
    let userID: String
    let campaigns: [CampaignModel]
    let testUser: Bool?
    
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case campaigns
        case testUser = "test_user"
    }
}

public struct CampaignResponse: Codable, Sendable {
    let userId: String?
    let messageId: String?
    let campaigns: [CampaignModel]?
    let metadata: Metadata?
    let sentAt: Int?

    enum CodingKeys: String, CodingKey {
        case userId
        case messageId = "message_id"
        case campaigns
        case metadata
        case sentAt = "sent_at"
    }
}

public struct Metadata: Codable, Sendable {
    let screenCaptureEnabled: Bool?
    let testUser: String?

    enum CodingKeys: String, CodingKey {
        case screenCaptureEnabled = "screen_capture_enabled"
        case testUser = "test_user"
    }
}


struct CampaignModel: Codable, Equatable, Sendable {
    let id: String
    let campaignType: String
    let position: String?
    let details: CampaignDetailsTwo
    let screen: String?
    let displayTrigger: Bool?
    let triggerEvent: String?
    
    static func == (lhs: CampaignModel, rhs: CampaignModel) -> Bool {
        return lhs.id == rhs.id &&
            lhs.campaignType == rhs.campaignType &&
            lhs.position == rhs.position
    }

    enum CodingKeys: String, CodingKey {
        case id
        case campaignType = "campaign_type"
        case position
        case details
        case screen
        case displayTrigger = "display_trigger"
        case triggerEvent = "trigger_event"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.campaignType = try container.decode(String.self, forKey: .campaignType)
        self.position = try container.decodeIfPresent(String.self, forKey: .position)
        self.screen = try container.decodeIfPresent(String.self, forKey: .screen)
        self.displayTrigger = try container.decodeIfPresent(Bool.self, forKey: .displayTrigger) 
        self.triggerEvent = try container.decodeIfPresent(String.self, forKey: .triggerEvent)
        
        switch campaignType {
        case "BAN":
            self.details = .banner(try container.decode(BannerDetails.self, forKey: .details))
        case "WID":
            self.details = .widget(try container.decode(WidgetDetails.self, forKey: .details))
        case "CSAT":
            do {
                let csatDetails = try container.decode(CsatDetails.self, forKey: .details)
                self.details = .csat(csatDetails)
            } catch {
                print("Failed to decode CsatDetails: \(error)")
                self.details = .unknown
            }
        case "PIP":
            if let pipDetails = try? container.decode(PipDetails.self, forKey: .details) {
                self.details = .pip(pipDetails)
            } else {
                self.details = .unknown
            }
        case "FLT":
            if let floaterDetails = try? container.decode(FloaterDetails.self, forKey: .details) {
                self.details = .floater(floaterDetails)
            } else {
                self.details = .unknown
            }
        case "SUR":
            do {
                let surveyDetails = try container.decode(SurveyDetails.self, forKey: .details)
                self.details = .survey(surveyDetails)
            } catch {
                print("Failed to decode SurveyDetails: \(error)")
                self.details = .unknown
            }
        case "STR":
            do {
                let storyDetails = try container.decode([StoryDetails].self, forKey: .details)
                self.details = .stories(storyDetails)
            } catch {
                self.details = .unknown
            }
        case "REL":
            do {
                let reelDetails = try container.decode(ReelsDetails.self, forKey: .details)
                self.details = .reel(reelDetails)
            } catch {
                self.details = .unknown
            }
        case "BTS":
            do {
                let bottomSheetDetails = try container.decode(BottomSheetDetails.self, forKey: .details)
                self.details = .bottomSheets(bottomSheetDetails)
            } catch {
                print("Failed to decode BottomSheetDetails: \(error)")
                self.details = .unknown
            }
        case "MOD":
            do {
                let modalsDetails = try container.decode(ModalsDetails.self, forKey: .details)
                self.details = .modals(modalsDetails)
            } catch {
                print("Failed to decode ModalsDetails: \(error)")
                self.details = .unknown
            }
        case "TTP":
            do {
                let tooltipDetails = try container.decode(TooltipDetails.self, forKey: .details)
                self.details = .toolTip(tooltipDetails)
            } catch {
                print("Failed to decode TooltipDetails: \(error)")
                self.details = .unknown
            }
        default:
            self.details = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(campaignType, forKey: .campaignType)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encodeIfPresent(screen, forKey: .screen)
        try container.encodeIfPresent(displayTrigger, forKey: .displayTrigger)
        switch details {
        case .banner(let bannerDetails):
            try container.encode(bannerDetails, forKey: .details)
        case .widget(let widgetDetails):
            try container.encode(widgetDetails, forKey: .details)
        case .csat(let csatDetails):
            try container.encode(csatDetails, forKey: .details)
        case .pip(let pipDetails):
            try container.encode(pipDetails, forKey: .details)
        case .toolTip(let toolTipDetails):
            try container.encode(toolTipDetails, forKey: .details)
        case .floater(let floaterDetails):
            try container.encode(floaterDetails, forKey: .details)
        case .survey(let surveyDetails):
            try container.encode(surveyDetails, forKey: .details)
        case .stories(let storiesDetails):
            try container.encode(storiesDetails, forKey: .details)
        case .reel(let reelDetails):
            try container.encode(reelDetails, forKey: .details)
        case .bottomSheets(let bottomSheetDetails):
            try container.encode(bottomSheetDetails, forKey: .details)
        case .modals(let modalsDetails):
            try container.encode(modalsDetails, forKey: .details)
        case .unknown:
            break
        }
    }
}

enum CampaignDetailsTwo : Sendable{
    case banner(BannerDetails)
    case widget(WidgetDetails)
    case csat(CsatDetails)
    case pip(PipDetails)
    case toolTip(TooltipDetails)
    case floater(FloaterDetails)
    case survey(SurveyDetails)
    case stories([StoryDetails])
    case reel(ReelsDetails)
    case bottomSheets(BottomSheetDetails)
    case modals(ModalsDetails)
    case unknown
    
    var widgetType: String? {
        if case let .widget(widgetDetails) = self {
            return widgetDetails.type
        }
        return nil
    }
}
struct ValidateAccountResponse: Codable {
    let access_token: String
    let refresh_token: String
}

struct TrackScreenResponse: Codable {
    let campaigns: [String]
}

struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let int64Value = try? container.decode(Int64.self) {
            self.value = int64Value
        } else if let uint64Value = try? container.decode(UInt64.self) {
            self.value = uint64Value
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            self.value = arrayValue
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            self.value = dictValue
        } else {
            throw DecodingError.typeMismatch(
                Any.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let value as Bool:
            try container.encode(value)
        case let value as Int:
            try container.encode(value)
        case let value as Int64:
            try container.encode(value)
        case let value as UInt64:
            try container.encode(value)
        case let value as Double:
            try container.encode(value)
        case let value as Float:
            try container.encode(value)
        case let value as String:
            try container.encode(value)
        case let value as [AnyCodable]:
            try container.encode(value)
        case let value as [String: AnyCodable]:
            try container.encode(value)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Unsupported type: \(type(of: value))"
                )
            )
        }
    }
}


extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}


extension AppStorys {
    
    // Updated showFloaterOverlay function
    func showFloaterOverlay(for campaign: CampaignModel) {
        self.floaterCampaigns = [campaign]
        guard !floaterCampaigns.isEmpty else { return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        // Extract floater details to calculate window frame
        guard case let .floater(details) = campaign.details else { return }
        
        let height = CGFloat(details.height ?? 60)
        let width = CGFloat(details.width ?? 60)
        let position = details.position ?? "right"
        let padding: CGFloat = 16 // Match your SwiftUI padding
        
        // Calculate window frame based on position
        let screenBounds = windowScene.coordinateSpace.bounds
        let windowFrame: CGRect
        
        switch position.lowercased() {
        case "left":
            windowFrame = CGRect(
                x: padding,
                y: screenBounds.height - height - padding - (window.safeAreaInsets.bottom),
                width: width,
                height: height
            )
        case "right":
            windowFrame = CGRect(
                x: screenBounds.width - width - padding,
                y: screenBounds.height - height - padding - (window.safeAreaInsets.bottom),
                width: width,
                height: height
            )
        default: // center or any other value
            windowFrame = CGRect(
                x: (screenBounds.width - width) / 2,
                y: screenBounds.height - height - padding - (window.safeAreaInsets.bottom),
                width: width,
                height: height
            )
        }
        
        let floaterView = OverlayFloater(apiService: self)
        let hostingController = PassThroughHostingController(rootView: floaterView)
        hostingController.view.backgroundColor = UIColor.clear
        
        let overlayWindow = PassThroughWindow(windowScene: windowScene)
        overlayWindow.frame = windowFrame // Set specific frame instead of full screen
        overlayWindow.rootViewController = hostingController
        overlayWindow.windowLevel = UIWindow.Level.alert
        overlayWindow.backgroundColor = UIColor.clear
        overlayWindow.isHidden = false
        
        self.floaterWindow = overlayWindow
    }

    func hideFloaterOverlay() {
        floaterWindow?.isHidden = true
        floaterWindow = nil
    }
}

extension AppStorys {
    func showBottomSheetOverlay(for campaign: CampaignModel) {
        self.bottomSheetsCampaigns = [campaign]
        guard !bottomSheetsCampaigns.isEmpty else { return }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        let bottomSheetView = BottomSheetView(apiService: self, isShowing: $isShowing)
        let hostingController = PassThroughHostingController(rootView: bottomSheetView)

        hostingController.view.backgroundColor = UIColor.clear

        let overlayWindow = PassThroughWindow(windowScene: windowScene)
        overlayWindow.rootViewController = hostingController
        overlayWindow.windowLevel = UIWindow.Level.alert + 10
        overlayWindow.backgroundColor = UIColor.clear
        overlayWindow.isHidden = false

        self.bottomSheetWindow = overlayWindow
    }

    func hideBottomSheetOverlay() {
        bottomSheetWindow?.isHidden = true
        bottomSheetWindow = nil
    }
}

extension AppStorys {
    func showModalOverlay(for campaign: CampaignModel) {
        self.modalsCampaigns = [campaign]
        guard !modalsCampaigns.isEmpty else { return }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let modalView = PopupModal(
            onCloseClick: { [weak self] in
                self?.hideModalOverlay()
            },
            apiService: self
        )
        let hostingController = UIHostingController(rootView: modalView)
        
        hostingController.view.backgroundColor = UIColor.clear
        
        let overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow.rootViewController = hostingController
        overlayWindow.windowLevel = UIWindow.Level.alert + 30
        overlayWindow.backgroundColor = UIColor.clear
        overlayWindow.isHidden = false
        
        self.modalWindow = overlayWindow
    }
    
    func hideModalOverlay() {
        modalWindow?.isHidden = true
        modalWindow = nil
    }

}
extension AppStorys {
    func showCsatOverlay(for campaign: CampaignModel) {
        self.csatCampaigns = [campaign]
        guard !csatCampaigns.isEmpty else { return }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        // Extract CSAT details to calculate window frame
        guard case .csat(_) = campaign.details else { return }
        
        let screenBounds = windowScene.coordinateSpace.bounds
        
        // Responsive sizing based on orientation and screen size
        let isLandscape = screenBounds.width > screenBounds.height
        let horizontalPadding: CGFloat = isLandscape ? max(40, screenBounds.width * 0.1) : 20
        let bottomPadding: CGFloat = isLandscape ? 15 : 20
        
        // Calculate CSAT window dimensions - responsive width
        let csatWidth = screenBounds.width - (horizontalPadding * 2)
        let maxWidth: CGFloat = isLandscape ? min(csatWidth, 600) : csatWidth // Max width in landscape
        let finalWidth = min(csatWidth, maxWidth)
        
        let estimatedHeight: CGFloat = isLandscape ? 250 : 300 // Adjust for landscape
        
        // Center horizontally in landscape, use padding in portrait
        let xPosition = isLandscape ? (screenBounds.width - finalWidth) / 2 : horizontalPadding
        
        // Calculate window frame (positioned at bottom)
        let windowFrame = CGRect(
            x: xPosition,
            y: screenBounds.height - estimatedHeight - window.safeAreaInsets.bottom - bottomPadding,
            width: finalWidth,
            height: estimatedHeight
        )
        
        let csatView = OverlayCsatView(apiService: self) { [weak self] newHeight in
            // Handle dynamic height updates for different CSAT states
            self?.updateCsatWindowFrame(newHeight: newHeight, campaign: campaign, windowScene: windowScene)
        }
        let hostingController = PassThroughHostingController(rootView: csatView)
        hostingController.view.backgroundColor = UIColor.clear
        
        let overlayWindow = PassThroughWindow(windowScene: windowScene)
        overlayWindow.frame = windowFrame // Set specific frame
        overlayWindow.rootViewController = hostingController
        overlayWindow.windowLevel = UIWindow.Level.alert + 30
        overlayWindow.backgroundColor = UIColor.clear
        overlayWindow.isHidden = false
        
        // Listen for orientation changes
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.updateCsatWindowForOrientationChange(campaign: campaign, windowScene: windowScene)
            }
        }
        
        self.csatWindow = overlayWindow
    }
    
    private func updateCsatWindowForOrientationChange(campaign: CampaignModel, windowScene: UIWindowScene) {
        guard let csatWindow = self.csatWindow,
              case .csat(_) = campaign.details else { return }
        
        let screenBounds = windowScene.coordinateSpace.bounds
        let isLandscape = screenBounds.width > screenBounds.height
        let horizontalPadding: CGFloat = isLandscape ? max(40, screenBounds.width * 0.1) : 20
        let bottomPadding: CGFloat = isLandscape ? 15 : 20
        
        // Calculate new responsive dimensions
        let csatWidth = screenBounds.width - (horizontalPadding * 2)
        let maxWidth: CGFloat = isLandscape ? min(csatWidth, 600) : csatWidth
        let finalWidth = min(csatWidth, maxWidth)
        
        let xPosition = isLandscape ? (screenBounds.width - finalWidth) / 2 : horizontalPadding
        let currentHeight = csatWindow.frame.height
        
        // Update window frame for new orientation
        let newFrame = CGRect(
            x: xPosition,
            y: screenBounds.height - currentHeight - (windowScene.windows.first?.safeAreaInsets.bottom ?? 0) - bottomPadding,
            width: finalWidth,
            height: currentHeight
        )
        
        // Animate the orientation change
        UIView.animate(withDuration: 0.3) {
            csatWindow.frame = newFrame
        }
    }
    
    private func updateCsatWindowFrame(newHeight: CGFloat, campaign: CampaignModel, windowScene: UIWindowScene) {
        guard let csatWindow = self.csatWindow,
              case .csat(_) = campaign.details else { return }
        
        let screenBounds = windowScene.coordinateSpace.bounds
        let isLandscape = screenBounds.width > screenBounds.height
        let horizontalPadding: CGFloat = isLandscape ? max(40, screenBounds.width * 0.1) : 20
        let bottomPadding: CGFloat = isLandscape ? 15 : 20
        
        // Calculate responsive dimensions
        let csatWidth = screenBounds.width - (horizontalPadding * 2)
        let maxWidth: CGFloat = isLandscape ? min(csatWidth, 600) : csatWidth
        let finalWidth = min(csatWidth, maxWidth)
        
        let xPosition = isLandscape ? (screenBounds.width - finalWidth) / 2 : horizontalPadding
        
        // Update window frame with new height
        let newFrame = CGRect(
            x: xPosition,
            y: screenBounds.height - newHeight - (windowScene.windows.first?.safeAreaInsets.bottom ?? 0) - bottomPadding,
            width: finalWidth,
            height: newHeight
        )
        
        // Animate the frame change
        UIView.animate(withDuration: 0.3) {
            csatWindow.frame = newFrame
        }
    }
    
    func hideCsatOverlay() {
        // Remove orientation observer
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        
        csatWindow?.isHidden = true
        csatWindow = nil
    }
}

extension AppStorys {
    func showPipOverlay(for campaign: CampaignModel) {
        self.pipCampaigns = [campaign]
        guard !pipCampaigns.isEmpty else { return }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        // Extract PIP details to calculate window frame
        guard case let .pip(details) = campaign.details else { return }
        
        let videoWidth = CGFloat(details.width ?? 230)
        let videoHeight = CGFloat(details.height ?? 405)
        let screenBounds = windowScene.coordinateSpace.bounds
        let safeArea = window.safeAreaInsets
        
        // Calculate initial position based on backend position setting
        let horizontalOffset = screenBounds.width / 2 - videoWidth / 2 - 10
        let verticalOffset = screenBounds.height / 2 - videoHeight / 2 - safeArea.bottom - 20
        
        let initialPosition: CGSize
        if let backendPosition = details.position?.lowercased() {
            switch backendPosition {
            case "right":
                initialPosition = CGSize(width: horizontalOffset, height: verticalOffset)
            case "left":
                initialPosition = CGSize(width: -horizontalOffset, height: verticalOffset)
            default:
                initialPosition = CGSize(width: horizontalOffset, height: verticalOffset)
            }
        } else {
            initialPosition = CGSize(width: horizontalOffset, height: verticalOffset)
        }
        
        // Calculate window frame based on initial position
        let windowFrame = CGRect(
            x: screenBounds.width / 2 + initialPosition.width - videoWidth / 2,
            y: screenBounds.height / 2 + initialPosition.height - videoHeight / 2,
            width: videoWidth,
            height: videoHeight
        )
        
        let pipView = OverlayPipView(
            apiService: self,
            positionUpdateCallback: { [weak self] newPosition in
                // Update window frame when PIP is dragged
                self?.updatePipWindowPosition(newPosition: newPosition, videoSize: CGSize(width: videoWidth, height: videoHeight), windowScene: windowScene)
            },
            showFullScreenCallback: { [weak self] in
                // Show full screen overlay that covers entire screen
                self?.showPipFullScreenOverlay()
            }
        )
        let hostingController = PassThroughHostingController(rootView: pipView)
        hostingController.view.backgroundColor = UIColor.clear
        
        let overlayWindow = PassThroughWindow(windowScene: windowScene)
        overlayWindow.frame = windowFrame // Set specific frame instead of full screen
        overlayWindow.rootViewController = hostingController
        overlayWindow.windowLevel = UIWindow.Level.alert + 20
        overlayWindow.backgroundColor = UIColor.clear
        overlayWindow.isHidden = false
        
        self.pipWindow = overlayWindow
    }
    
    func showPipFullScreenOverlay() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        // Hide the PIP window while in full screen
        pipWindow?.isHidden = true
        
        let fullScreenView = FullScreenPipView(
            apiService: self,
            hideFullScreenCallback: { [weak self] in
                // Hide full screen callback
                self?.hidePipFullScreenOverlay()
            }
        )
        let hostingController = PassThroughHostingController(rootView: fullScreenView)
        hostingController.view.backgroundColor = UIColor.black
        
        // Create full screen window that covers entire screen
        let fullScreenWindow = PassThroughWindow(windowScene: windowScene)
        fullScreenWindow.frame = windowScene.coordinateSpace.bounds // Full screen bounds
        fullScreenWindow.rootViewController = hostingController
        fullScreenWindow.windowLevel = UIWindow.Level.alert + 25 // Higher than PIP
        fullScreenWindow.backgroundColor = UIColor.black
        fullScreenWindow.isHidden = false
        
        self.pipFullScreenWindow = fullScreenWindow
    }
    
    func hidePipFullScreenOverlay() {
        pipFullScreenWindow?.isHidden = true
        pipFullScreenWindow = nil
        
        // Show the PIP window again
        pipWindow?.isHidden = false
    }
    
    private func updatePipWindowPosition(newPosition: CGSize, videoSize: CGSize, windowScene: UIWindowScene) {
        guard let pipWindow = self.pipWindow else { return }
        
        let screenBounds = windowScene.coordinateSpace.bounds
        
        // Calculate new window frame based on the drag position
        let newFrame = CGRect(
            x: screenBounds.width / 2 + newPosition.width - videoSize.width / 2,
            y: screenBounds.height / 2 + newPosition.height - videoSize.height / 2,
            width: videoSize.width,
            height: videoSize.height
        )
        
        // Update window frame smoothly
        UIView.animate(withDuration: 0.1) {
            pipWindow.frame = newFrame
        }
    }
    
    func hidePipOverlay() {
        pipWindow?.isHidden = true
        pipWindow = nil
        pipFullScreenWindow?.isHidden = true
        pipFullScreenWindow = nil
    }
}

extension AppStorys {
    func showSurveyOverlay(for campaign: CampaignModel) {
        self.surveyCampaigns = [campaign]
        guard !surveyCampaigns.isEmpty else { return }
        
        // Get the current window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        // Create a hosting controller for the SwiftUI Survey view
        let surveyView = Survey(apiService: self)
        let hostingController = UIHostingController(rootView: surveyView)
        hostingController.view.backgroundColor = UIColor.clear
        
        // Create a new window for the Survey overlay
        let overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow.rootViewController = hostingController
        overlayWindow.windowLevel = UIWindow.Level.alert + 40 // Priority between Floater and PIP
        overlayWindow.backgroundColor = UIColor.clear
        overlayWindow.isHidden = false
        
        // Store reference to prevent deallocation
        self.surveyWindow = overlayWindow
    }
    
    func hideSurveyOverlay() {
        surveyWindow?.isHidden = true
        surveyWindow = nil
    }
}
extension AppStorys {
    func showBannerOverlay(for campaign: CampaignModel) {
        self.banCampaigns = [campaign]
        guard !banCampaigns.isEmpty else { return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        // Extract banner details to calculate window frame
        guard case let .banner(details) = campaign.details else { return }
        
        let styling = details.styling
        let marginLeft = CGFloat(styling?.marginLeft.flatMap(Double.init) ?? 0)
        let marginRight = CGFloat(styling?.marginRight.flatMap(Double.init) ?? 0)
        let marginBottom = CGFloat(styling?.marginBottom.flatMap(Double.init) ?? 0)
        
        // Get current screen bounds (responsive to orientation)
        let screenBounds = windowScene.coordinateSpace.bounds
        let bannerWidth = screenBounds.width - marginLeft - marginRight
        
        // Calculate height based on banner content
        var bannerHeight: CGFloat = 200 // Default height
        
        if let width = details.width, let height = details.height {
            let aspectRatio = height / width
            bannerHeight = bannerWidth * CGFloat(aspectRatio)
        } else if let height = details.height {
            bannerHeight = CGFloat(height)
        }
        
        // Add some padding for close button if present
        let showCloseButton = styling?.enableCloseButton ?? true
        let closeButtonPadding: CGFloat = showCloseButton ? 40 : 0 // Increased padding for better positioning
        
        // Get safe area insets
        let safeAreaBottom = windowScene.windows.first?.safeAreaInsets.bottom ?? 0
        
        // Calculate window frame (positioned at bottom with proper safe area handling)
        let windowFrame = CGRect(
            x: marginLeft,
            y: screenBounds.height - bannerHeight - marginBottom - safeAreaBottom - closeButtonPadding,
            width: bannerWidth,
            height: bannerHeight + closeButtonPadding
        )
        
        let bannerView = OverlayBannerView(apiService: self) { [weak self] height in
            // Handle dynamic height updates
            self?.updateBannerWindowFrame(newHeight: height, campaign: campaign)
        }
        let hostingController = PassThroughHostingController(rootView: bannerView)
        hostingController.view.backgroundColor = .clear
        
        let overlayWindow = PassThroughWindow(windowScene: windowScene)
        overlayWindow.frame = windowFrame
        overlayWindow.rootViewController = hostingController
        overlayWindow.windowLevel = .alert + 10
        overlayWindow.backgroundColor = .clear
        overlayWindow.isHidden = false
        
        self.bannerWindow = overlayWindow
        
        // Listen for orientation changes to update window frame
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.updateBannerWindowFrameForOrientation(campaign: campaign)
            }
        }
    }
    
    private func updateBannerWindowFrame(newHeight: CGFloat, campaign: CampaignModel) {
        guard let bannerWindow = self.bannerWindow,
              case let .banner(details) = campaign.details,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        let styling = details.styling
        let marginLeft = CGFloat(styling?.marginLeft.flatMap(Double.init) ?? 0)
        let marginRight = CGFloat(styling?.marginRight.flatMap(Double.init) ?? 0)
        let marginBottom = CGFloat(styling?.marginBottom.flatMap(Double.init) ?? 0)
        let showCloseButton = styling?.enableCloseButton ?? true
        let closeButtonPadding: CGFloat = showCloseButton ? 40 : 0
        
        let screenBounds = windowScene.coordinateSpace.bounds
        let bannerWidth = screenBounds.width - marginLeft - marginRight
        let safeAreaBottom = windowScene.windows.first?.safeAreaInsets.bottom ?? 0
        
        // Update window frame with new height
        let newFrame = CGRect(
            x: marginLeft,
            y: screenBounds.height - newHeight - marginBottom - safeAreaBottom - closeButtonPadding,
            width: bannerWidth,
            height: newHeight + closeButtonPadding
        )
        
        // Animate the frame change
        UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            bannerWindow.frame = newFrame
        }
    }
    
    private func updateBannerWindowFrameForOrientation(campaign: CampaignModel) {
        guard let bannerWindow = self.bannerWindow,
              case let .banner(details) = campaign.details,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        let styling = details.styling
        let marginLeft = CGFloat(styling?.marginLeft.flatMap(Double.init) ?? 0)
        let marginRight = CGFloat(styling?.marginRight.flatMap(Double.init) ?? 0)
        let marginBottom = CGFloat(styling?.marginBottom.flatMap(Double.init) ?? 0)
        let showCloseButton = styling?.enableCloseButton ?? true
        let closeButtonPadding: CGFloat = showCloseButton ? 40 : 0
        
        // Get updated screen bounds after orientation change
        let screenBounds = windowScene.coordinateSpace.bounds
        let bannerWidth = screenBounds.width - marginLeft - marginRight
        
        // Recalculate height based on new width
        var bannerHeight: CGFloat = 200
        if let width = details.width, let height = details.height {
            let aspectRatio = height / width
            bannerHeight = bannerWidth * CGFloat(aspectRatio)
        } else if let height = details.height {
            bannerHeight = CGFloat(height)
        }
        
        let safeAreaBottom = windowScene.windows.first?.safeAreaInsets.bottom ?? 0
        
        // Update window frame for new orientation
        let newFrame = CGRect(
            x: marginLeft,
            y: screenBounds.height - bannerHeight - marginBottom - safeAreaBottom - closeButtonPadding,
            width: bannerWidth,
            height: bannerHeight + closeButtonPadding
        )
        
        // Animate the frame change for orientation
        UIView.animate(withDuration: 0.4, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            bannerWindow.frame = newFrame
        } completion: { _ in
            // Force a layout update
            bannerWindow.rootViewController?.view.setNeedsLayout()
            bannerWindow.rootViewController?.view.layoutIfNeeded()
        }
    }
    
    func hideBannerOverlay() {
        // Remove orientation observer
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        
        bannerWindow?.isHidden = true
        bannerWindow = nil
    }
}

class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        
        // Debug print to see what's being hit
        print("Hit testing point: \(point), hitView: \(String(describing: hitView))")
        
        // If we hit something, always return it (let SwiftUI handle the touch)
        if let hitView = hitView {
            // Don't pass through if we hit any view within our window
            return hitView
        }
        
        // Only return nil if we didn't hit anything
        return nil
    }
}

class PassThroughHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.clear
    }
}
