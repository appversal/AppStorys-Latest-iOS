//
//  ScreenCaptureManager.swift
//  AppStorys_iOS
//
//  Enhanced with render waiting and JPEG compression
//

import UIKit

/// Handles screen capture and upload
actor ScreenCaptureManager {
    private let authManager: AuthManager
    private let baseURL: String
    private var lastCaptureTime: Date?
    
    // Rate limiting: 5 seconds between captures
    private let minimumCaptureInterval: TimeInterval = 5.0
    
    // ✅ NEW: Render waiting configuration (Flutter pattern)
    private let maxRenderRetries = 10
    private let renderDelayMs: UInt64 = 50
    
    init(authManager: AuthManager, baseURL: String) {
        self.authManager = authManager
        self.baseURL = baseURL
    }
    
    /// Capture screen and upload to backend
    func captureAndUpload(
        screenName: String,
        userId: String,
        rootView: UIView
    ) async throws {
        // ✅ Rate limit check
        if let lastCapture = lastCaptureTime,
           Date().timeIntervalSince(lastCapture) < minimumCaptureInterval {
            Logger.warning("⏳ Rate limited: Please wait \(Int(minimumCaptureInterval))s between captures")
            throw ScreenCaptureError.rateLimitExceeded
        }
        
        lastCaptureTime = Date()
        Logger.info("📸 Starting screen capture for: \(screenName)")
        
        // ✅ NEW: Wait for render completion before capturing
        await MainActor.run {
            waitForRenderCompletion(of: rootView)
        }
        
        // Step 1: Capture screenshot (main thread)
        let screenshot = try await MainActor.run {
            try captureScreenshot(from: rootView)
        }
        
        // ✅ CHANGED: Use JPEG instead of PNG (3-5x smaller)
        guard let imageData = screenshot.jpegData(compressionQuality: 0.8) else {
            Logger.error("❌ Failed to compress screenshot to JPEG")
            throw ScreenCaptureError.screenshotFailed
        }
        
        Logger.debug("✅ Screenshot: \(imageData.count / 1024)KB")
        
        // Step 2: Extract layout (main thread)
        let layoutInfo = await MainActor.run {
            extractLayoutInfo(from: rootView)
        }
        
        Logger.debug("✅ Layout: \(layoutInfo.count) elements")
        
        // ✅ Validate we have elements
        guard !layoutInfo.isEmpty else {
            Logger.warning("⚠️ No elements found - did you tag views with accessibilityIdentifier?")
            throw ScreenCaptureError.screenshotFailed
        }
        
        // Step 3: Upload
        try await uploadCapture(
            screenName: screenName,
            userId: userId,
            imageData: imageData,
            layoutInfo: layoutInfo
        )
        
        Logger.info("✅ Screen capture uploaded")
    }
    
    // MARK: - Private Methods
    
    /// ✅ NEW: Wait for view hierarchy to finish rendering (Flutter pattern)
    @MainActor
    private func waitForRenderCompletion(of view: UIView) {
        var retries = 0
        
        while retries < maxRenderRetries {
            // Force layout if needed
            if view.layer.needsLayout() {
                Logger.debug("⏳ Waiting for render (\(retries + 1)/\(maxRenderRetries))...")
                view.layoutIfNeeded()
                
                // Small delay to let render complete
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
        
        // ✅ Validate image size and throw if invalid
        guard image.size.width > 0 && image.size.height > 0 else {
            Logger.error("❌ Captured image has zero size")
            throw ScreenCaptureError.screenshotFailed
        }
        
        return image
    }
    
    @MainActor
    private func extractLayoutInfo(from rootView: UIView) -> [LayoutElement] {
        var elements: [LayoutElement] = []
        var seenIds = Set<String>()
        let pixelRatio = UIScreen.main.scale
        
        // ✅ FIX: Define prefix as local constant
        let capturePrefix = "APPSTORYS_"
        
        func traverse(view: UIView, depth: Int = 0) {
            guard !view.isHidden && view.alpha > 0 else { return }
            
            if let identifier = view.accessibilityIdentifier,
               !identifier.isEmpty,
               identifier.hasPrefix(capturePrefix) {
                
                let cleanId = String(identifier.dropFirst(capturePrefix.count))
                
                guard !seenIds.contains(cleanId) else {
                    return
                }
                
                seenIds.insert(cleanId)
                
                let frame = view.convert(view.bounds, to: rootView)
                
                elements.append(LayoutElement(
                    id: cleanId,
                    frame: LayoutFrame(
                        x: Int(frame.origin.x * pixelRatio),
                        y: Int(frame.origin.y * pixelRatio),
                        width: Int(frame.size.width * pixelRatio),
                        height: Int(frame.size.height * pixelRatio)
                    ),
                    type: String(describing: type(of: view)),
                    depth: depth
                ))
                
                Logger.debug("  📍 \(cleanId): \(frame)")
            }
            
            for subview in view.subviews {
                traverse(view: subview, depth: depth + 1)
            }
        }
        
        traverse(view: rootView)
        return elements
    }
    
    private func uploadCapture(
        screenName: String,
        userId: String,
        imageData: Data,
        layoutInfo: [LayoutElement]
    ) async throws {
        // ✅ Use backend URL (not users URL)
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
        
        // Add fields
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"screenName\"\r\n\r\n")
        body.append("\(screenName)\r\n")
        
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n")
        body.append("\(userId)\r\n")
        
        // Add layout JSON
        let layoutJson = try JSONEncoder().encode(layoutInfo)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"children\"\r\n")
        body.append("Content-Type: application/json\r\n\r\n")
        body.append(layoutJson)
        body.append("\r\n")
        
        // ✅ CHANGED: Upload as JPEG, not PNG
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"screenshot\"; filename=\"\(randomFileName).jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        
        request.httpBody = body
        
        Logger.debug("📤 Uploading \(body.count / 1024)KB to \(url.absoluteString)")
        
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
        
        Logger.info("✅ Upload successful")
    }
}

// MARK: - Models

struct LayoutElement: Codable {
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
