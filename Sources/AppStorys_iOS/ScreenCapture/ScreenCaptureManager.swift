//
//  ScreenCaptureManager.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Element tagging is now OPTIONAL - screenshot always works
//

import UIKit

/// Handles screen capture and upload
actor ScreenCaptureManager {
    private let authManager: AuthManager
    private let baseURL: String
    private let elementRegistry: ElementRegistry
    private var lastCaptureTime: Date?
    
    // Rate limiting: 5 seconds between captures
    private let minimumCaptureInterval: TimeInterval = 5.0
    
    // Render waiting configuration
    private let maxRenderRetries = 10
    private let renderDelayMs: UInt64 = 50
    
    init(
        authManager: AuthManager,
        baseURL: String,
        elementRegistry: ElementRegistry
    ) {
        self.authManager = authManager
        self.baseURL = baseURL
        self.elementRegistry = elementRegistry
    }
    
    /// Capture screen and upload to backend
    func captureAndUpload(
        screenName: String,
        userId: String,
        rootView: UIView
    ) async throws {
        // Rate limit check
        if let lastCapture = lastCaptureTime,
           Date().timeIntervalSince(lastCapture) < minimumCaptureInterval {
            Logger.warning("⏳ Rate limited: Please wait \(Int(minimumCaptureInterval))s between captures")
            throw ScreenCaptureError.rateLimitExceeded
        }
        
        lastCaptureTime = Date()
        Logger.info("📸 Starting screen capture for: \(screenName)")
        
        // Wait for render completion before capturing
        await MainActor.run {
            waitForRenderCompletion(of: rootView)
        }
        
        // Step 1: Capture screenshot (REQUIRED - main thread)
        let screenshot = try await MainActor.run {
            try captureScreenshot(from: rootView)
        }
        
        // Use JPEG compression (3-5x smaller than PNG)
        guard let imageData = screenshot.jpegData(compressionQuality: 0.8) else {
            Logger.error("❌ Failed to compress screenshot to JPEG")
            throw ScreenCaptureError.screenshotFailed
        }
        
        Logger.debug("✅ Screenshot: \(imageData.count / 1024)KB")
        
        // Step 2: Extract layout (OPTIONAL - best effort)
        let layoutInfo = await MainActor.run {
            // Discover elements (uses cache if available)
            _ = elementRegistry.discoverElements(in: rootView, forceRefresh: false)
            
            // Extract in backend-compatible format
            return elementRegistry.extractLayoutData()
        }
        
        // ✅ FIXED: Elements are optional, not required
        if layoutInfo.isEmpty {
            Logger.info("ℹ️ No tagged elements found (this is optional)")
            Logger.debug("   💡 Add .captureAppStorysTag(\"id\") to views for element tracking")
        } else {
            Logger.debug("✅ Layout: \(layoutInfo.count) tagged elements")
        }
        
        // Step 3: Upload (works with or without elements)
        try await uploadCapture(
            screenName: screenName,
            userId: userId,
            imageData: imageData,
            layoutInfo: layoutInfo  // ✅ Can be empty array
        )
        
        Logger.info("✅ Screen capture uploaded successfully")
    }
    
    // MARK: - Private Methods
    
    /// Wait for view hierarchy to finish rendering
    @MainActor
    private func waitForRenderCompletion(of view: UIView) {
        var retries = 0
        
        while retries < maxRenderRetries {
            if view.layer.needsLayout() {
                Logger.debug("⏳ Waiting for render (\(retries + 1)/\(maxRenderRetries))...")
                view.layoutIfNeeded()
                Thread.sleep(forTimeInterval: Double(renderDelayMs) / 1000.0)
                retries += 1
            } else {
                Logger.debug("✅ Render complete after \(retries) retries")
                return
            }
        }
        
        Logger.warning("⚠️ Max render retries reached, proceeding anyway")
    }
    
    @MainActor
    private func captureScreenshot(from view: UIView) throws -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { context in
            let success = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            if !success {
                Logger.warning("⚠️ drawHierarchy returned false - screenshot may be incomplete")
            }
        }
        
        // Validate image size
        guard image.size.width > 0 && image.size.height > 0 else {
            Logger.error("❌ Captured image has zero size")
            throw ScreenCaptureError.screenshotFailed
        }
        
        return image
    }
    
    private func uploadCapture(
        screenName: String,
        userId: String,
        imageData: Data,
        layoutInfo: [LayoutElement]
    ) async throws {
        // Use backend URL (not users URL)
        let endpoint = "\(baseURL.replacingOccurrences(of: "users", with: "backend"))/api/v2/appinfo/identify-elements/"
        
        guard let url = URL(string: endpoint) else {
            Logger.error("❌ Invalid URL: \(endpoint)")
            throw ScreenCaptureError.invalidURL
        }
        
        let accessToken = try await authManager.getAccessToken()
        
        // Build multipart request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        var body = Data()
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomSuffix = UUID().uuidString.prefix(6)
        let randomFileName = "screenshot_\(screenName)_\(timestamp)_\(randomSuffix).jpg"
        
        // Add required fields
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"screenName\"\r\n\r\n")
        body.append("\(screenName)\r\n")
        
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n")
        body.append("\(userId)\r\n")
        
        // ✅ Add layout JSON (even if empty array)
        let layoutJson = try JSONEncoder().encode(layoutInfo)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"children\"\r\n")
        body.append("Content-Type: application/json\r\n\r\n")
        body.append(layoutJson)
        body.append("\r\n")
        
        // Add screenshot (JPEG)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"screenshot\"; filename=\"\(randomFileName)\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        
        request.httpBody = body
        
        Logger.debug("📤 Uploading to \(url.absoluteString)")
        Logger.debug("   Screenshot: \(imageData.count / 1024)KB")
        Logger.debug("   Elements: \(layoutInfo.count)")
        Logger.debug("   Total size: \(body.count / 1024)KB")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.error("❌ Invalid HTTP response")
            throw ScreenCaptureError.invalidResponse
        }
        
        Logger.debug("📥 Response: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorMsg = String(data: data, encoding: .utf8) {
                Logger.error("❌ Upload failed [\(httpResponse.statusCode)]: \(errorMsg)")
            }
            throw ScreenCaptureError.serverError(httpResponse.statusCode)
        }
        
        // ✅ Log success with details
        if let responseBody = String(data: data, encoding: .utf8) {
            Logger.debug("✅ Server response: \(responseBody)")
        }
        
        Logger.info("✅ Upload successful - Screen: \(screenName), Elements: \(layoutInfo.count)")
    }
}

// MARK: - Models

public struct LayoutElement: Codable, Sendable {
    let id: String
    let frame: LayoutFrame
    let type: String?
    let depth: Int?
}

struct LayoutFrame: Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

// MARK: - Helpers

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
