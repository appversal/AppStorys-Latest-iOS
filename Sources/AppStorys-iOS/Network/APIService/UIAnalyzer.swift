//
//  AA.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 30/07/25.
//

import UIKit
import SwiftUI
import Security
import Foundation

//Used to save and retrieve values - just like User defaults
public class KeychainHelper {
    @MainActor static let shared = KeychainHelper()
        private init() {}

    func save(_ value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
        func get(key: String) -> String? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)

            guard status == errSecSuccess, let data = item as? Data else {
                return nil
            }

            return String(data: data, encoding: .utf8)
        }

        func delete(key: String) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]

            SecItemDelete(query as CFDictionary)
        }
}

internal class AppStoryTargetView: UIView {
    let appstoryID: String?
    init(identifier: String?) {
        self.appstoryID = identifier
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        self.accessibilityIdentifier = identifier
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public struct ElementUploadPayload: Codable {
    let screenName: String
    let children: [ElementFrame]

    struct ElementFrame: Codable {
        let id: String
        let frame: FrameWithScreenSize

        struct FrameWithScreenSize: Codable {
            let x: CGFloat
            let y: CGFloat
            let width: CGFloat
            let height: CGFloat
            let screenWidth: CGFloat
            let screenHeight: CGFloat
        }

        init(id: String, frame: CGRect, screenWidth: CGFloat, screenHeight: CGFloat) {
            self.id = id
            self.frame = FrameWithScreenSize(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.size.width,
                height: frame.size.height,
                screenWidth: screenWidth,
                screenHeight: screenHeight
            )
        }
    }
}


@MainActor
public class UIAnalyzer {
    
    static var analyzedElements: [(id: String, frame: CGRect)] = []
    
    @MainActor
    public static func analyzeCurrentScreen(screenName: String) {

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: \.isKeyWindow) else {
            print("No key window found.")
            return
        }

        print("\n📱 Analyzing screen: \(screenName)")
        print("🔍 Tagged Elements with Frames:\n")

        analyzedElements.removeAll()
        traverseViewHierarchy(view: keyWindow)
        for element in analyzedElements {
            print("🆔 ID: \(element.id)\n↪️ Frame: \(element.frame)\n")
        }

        let screenWidth = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height

            let children: [ElementUploadPayload.ElementFrame] = analyzedElements.map {
                ElementUploadPayload.ElementFrame(id: $0.id, frame: $0.frame, screenWidth: screenWidth, screenHeight: screenHeight)
            }
        print("📦 Prepared \(children.count) elements for upload.")
        showCaptureButton(screenName: screenName, children: children)
    }
    
    private static var captureButton: UIButton?
    private static var captureOverlayView: UIView?

    @MainActor
    private static func showCaptureButton(screenName: String, children: [ElementUploadPayload.ElementFrame]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: \.isKeyWindow) else {
            print("No key window found for capture button.")
            return
        }
        removeCaptureButton()
        
        // Create overlay view
        let overlayView = UIView(frame: keyWindow.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlayView.alpha = 0
        captureOverlayView = overlayView
        
        // Create capture button
        let button = UIButton(type: .system)
        button.setTitle("📸 Capture & Send", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 4
        
        // Position button at bottom center
        button.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            button.widthAnchor.constraint(equalToConstant: 200),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Add tap action
        button.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        captureButton = button
        
        // Store data for later use
        captureData = CaptureData(screenName: screenName, children: children)
        
        // Add to window
        keyWindow.addSubview(overlayView)
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            overlayView.alpha = 1
        }
        
        // Add dismiss gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissCaptureButton))
        overlayView.addGestureRecognizer(tapGesture)
        
        print("🎯 Capture button displayed. Tap to send data to backend.")
    }

    // Data structure to hold capture information
    private struct CaptureData {
        let screenName: String
        let children: [ElementUploadPayload.ElementFrame]
    }

    private static var captureData: CaptureData?

    @MainActor
    @objc private static func captureButtonTapped() {
        guard let data = captureData else {
            print("❌ No capture data available")
            removeCaptureButton()
            return
        }
        
        print("📸 Capture button tapped! Processing screenshot and upload...")
        captureOverlayView?.alpha = 0
        captureOverlayView?.removeFromSuperview()
        
        // Longer delay to ensure UI is completely updated and rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let screenshotImage = captureScreenshot(),
                  let screenshotData = screenshotImage.jpegData(compressionQuality: 0.8) else {
                print("❌ Failed to capture screenshot.")
                removeCaptureButton()
                return
            }
            
            let payload = ElementUploadPayload(screenName: data.screenName, children: data.children)
            
            print("✅ Screenshot captured successfully without overlay!")
            DispatchQueue.main.async {
                let imageView = UIImageView(image: screenshotImage)
                imageView.frame = UIScreen.main.bounds
                imageView.contentMode = .scaleAspectFit
                imageView.backgroundColor = UIColor.black.withAlphaComponent(0.9)
                imageView.isUserInteractionEnabled = true
                imageView.tag = 9999
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissPreviewImage(_:)))
                imageView.addGestureRecognizer(tapGesture)

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    keyWindow.addSubview(imageView)
                } else {
                    print("❌ Could not find key window to add image view")
                }
            }


            
            Task {
                await uploadElementsData(payload: payload, screenshotData: screenshotData)
                await MainActor.run {
                    captureOverlayView = nil
                    captureButton = nil
                    captureData = nil
                    print("✅ Upload completed and UI cleaned up!")
                }
            }
        }
    }
    @objc private static func dismissPreviewImage(_ sender: UITapGestureRecognizer) {
        sender.view?.removeFromSuperview()
    }

    @MainActor
    @objc private static func dismissCaptureButton() {
        removeCaptureButton()
    }
    
    @MainActor
    private static func removeCaptureButton() {
        guard let overlayView = captureOverlayView else { return }
        
        UIView.animate(withDuration: 0.3, animations: {
            overlayView.alpha = 0
        }) { _ in
            overlayView.removeFromSuperview()
            captureOverlayView = nil
            captureButton = nil
            captureData = nil
        }
    }

    @MainActor
    private static func traverseViewHierarchy(view: UIView) {
        let frame = view.convert(view.bounds, to: nil)
        if let targetView = view as? AppStoryTargetView,
           let identifier = targetView.appstoryID ?? targetView.accessibilityIdentifier {
            analyzedElements.append((id: identifier, frame: frame))
        }
        for subview in view.subviews {
            traverseViewHierarchy(view: subview)
        }
    }


    @MainActor private static func captureScreenshot() -> UIImage? {
            guard let window = UIApplication.shared.windows.first else { return nil }
    
            let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
            let image = renderer.image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            return image
        }
   
    @MainActor public static func uploadElementsData(payload: ElementUploadPayload, screenshotData: Data) {
    
            guard let url = URL(string: "https://backend.appstorys.com/api/v1/appinfo/identify-elements/") else {
                print("Invalid URL")
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            guard let userID = KeychainHelper.shared.get(key: "userIDAppStorys"),
                  let accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys") else {
                return
            }
    
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"screenName\"\r\n\r\n")
            body.append(payload.screenName)
            body.append("\r\n")
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"children\"\r\n")
            body.append("Content-Type: application/json\r\n\r\n")
            do {
                let childrenData = try JSONEncoder().encode(payload.children)
                if let childrenJSONString = String(data: childrenData, encoding: .utf8) {
                    body.append("--\(boundary)\r\n")
                    body.append("Content-Disposition: form-data; name=\"children\"\r\n")
                    body.append("Content-Type: application/json\r\n\r\n")
                    body.append(childrenJSONString)
                    body.append("\r\n")
                }
            } catch {
                print("Error encoding children list: \(error)")
                return
            }
            let uuid = UUID().uuidString
            body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"screenshot\"; filename=\"screenshot\(uuid).jpg\"\r\n")
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(screenshotData)
            body.append("\r\n")
            body.append("--\(boundary)--\r\n")
    
            request.httpBody = body
            if let bodyString = String(data: body, encoding: .utf8) {
                print("Request Body: \(bodyString)")
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Upload error: \(error.localizedDescription)")
                    return
                }
    
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response")
                    return
                }
    
                print("Upload completed with status: \(httpResponse.statusCode)")
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseBody)")
                }
            }.resume()
        }
       
//    for tooltip mainly
    @MainActor
    public static func showTooltip(forID id: String?, frame: CGRect?, tooltip: Tooltip, completion: @escaping () -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            print("No window available.")
            return
        }

        var targetFrame: CGRect?
        if let frame = frame {
            targetFrame = frame
        } else if let id = id,
                  let targetView = findView(in: window, withAccessibilityIdentifier: id) {
            let padding = tooltip.styling?.highlightPadding?.cgFloatValue ?? 8
            targetFrame = targetView.convert(targetView.bounds, to: window).insetBy(dx: -padding, dy: -padding)
        }

        guard let highlightFrame = targetFrame else {
            print("Tooltip frame could not be determined.")
            return
        }

        let styling = tooltip.styling
        let dimensions = styling?.tooltipDimensions
        let spacing = styling?.spacing?.padding
        let arrowSize = CGSize(
            width: styling?.tooltipArrow?.arrowWidth?.cgFloatValue ?? 12,
            height: styling?.tooltipArrow?.arrowHeight?.cgFloatValue ?? 8
        )

        let dimView = UIView(frame: window.bounds)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = .clear

            let path = UIBezierPath(rect: window.bounds)
            let cornerRadius = styling?.highlightRadius?.cgFloatValue ?? 8
            let highlightPath = UIBezierPath(roundedRect: highlightFrame, cornerRadius: cornerRadius)
            path.append(highlightPath)
            path.usesEvenOddFillRule = true

            let maskLayer = CAShapeLayer()
            maskLayer.path = path.cgPath
            maskLayer.fillRule = .evenOdd
            maskLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
            dimView.layer.addSublayer(maskLayer)

        let tooltipView: UIView
        if tooltip.type?.lowercased() == "image", let imageUrlString = tooltip.url, let imageUrl = URL(string: imageUrlString) {
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.layer.cornerRadius = dimensions?.cornerRadiusValue ?? 8
            imageView.layer.masksToBounds = true
            imageView.backgroundColor = UIColor(hex: styling?.backgroundColor ?? "#000000", alpha: 0.9)
            tooltipView = imageView

            URLSession.shared.dataTask(with: imageUrl) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        imageView.image = image
                    }
                }
            }.resume()
        } else {
            let label = UILabel()
            label.text = tooltip.link ?? tooltip.url ?? tooltip.type ?? "Tooltip"
            label.textColor = .white
            label.backgroundColor = UIColor(hex: styling?.backgroundColor ?? "#000000", alpha: 0.9)
            label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.layer.cornerRadius = dimensions?.cornerRadiusValue ?? 8
            label.layer.masksToBounds = true
            label.translatesAutoresizingMaskIntoConstraints = false
            tooltipView = label
        }

        // Arrow view
        let arrowView = UIView()
        arrowView.backgroundColor = .clear
        arrowView.translatesAutoresizingMaskIntoConstraints = false

        let arrowLayer = CAShapeLayer()
        let arrowPath = UIBezierPath()
        arrowPath.move(to: .zero)
        arrowPath.addLine(to: CGPoint(x: arrowSize.width, y: 0))
        arrowPath.addLine(to: CGPoint(x: arrowSize.width / 2, y: arrowSize.height))
        arrowPath.close()
        arrowLayer.path = arrowPath.cgPath

        // Rotate arrow based on position
        switch tooltip.position?.lowercased() {
        case "top":
            arrowView.transform = CGAffineTransform.identity
          
        case "bottom":
            arrowView.transform = CGAffineTransform(rotationAngle: .pi) // Point down
        case "left":
            arrowView.transform = CGAffineTransform.identity // Point up
          
        case "right":
            arrowView.transform = CGAffineTransform(rotationAngle: .pi / 2) // Point left
        default:
            arrowView.transform = CGAffineTransform.identity
        }

        arrowLayer.fillColor = UIColor(hex: styling?.backgroundColor ?? "#FFFFFF", alpha: 0.9)?.cgColor
        arrowView.layer.addSublayer(arrowLayer)
        window.addSubview(dimView)
        dimView.addSubview(tooltipView)
        dimView.addSubview(arrowView)

        let paddingTop = CGFloat(spacing?.paddingTop ?? 0)
        let paddingLeft = CGFloat(spacing?.paddingLeft ?? 0)
        let width = dimensions?.widthValue ?? 250
        let height = dimensions?.heightValue ?? 150
        
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: window.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: window.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: window.trailingAnchor),
        ])

        switch tooltip.position?.lowercased() {
        case "top":
            NSLayoutConstraint.activate([
                tooltipView.bottomAnchor.constraint(equalTo: dimView.topAnchor, constant: highlightFrame.minY - arrowSize.height - paddingTop),
                tooltipView.centerXAnchor.constraint(equalTo: dimView.leadingAnchor, constant: highlightFrame.midX + paddingLeft),
                tooltipView.widthAnchor.constraint(equalToConstant: width),
                tooltipView.heightAnchor.constraint(equalToConstant: height),

                arrowView.topAnchor.constraint(equalTo: tooltipView.bottomAnchor),
                arrowView.centerXAnchor.constraint(equalTo: tooltipView.centerXAnchor),
                arrowView.widthAnchor.constraint(equalToConstant: arrowSize.width),
                arrowView.heightAnchor.constraint(equalToConstant: arrowSize.height)
            ])

        case "bottom":
            NSLayoutConstraint.activate([
                tooltipView.topAnchor.constraint(equalTo: dimView.topAnchor, constant: highlightFrame.maxY + arrowSize.height + paddingTop),
                tooltipView.centerXAnchor.constraint(equalTo: dimView.leadingAnchor, constant: highlightFrame.midX + paddingLeft),
                tooltipView.widthAnchor.constraint(equalToConstant: width),
                tooltipView.heightAnchor.constraint(equalToConstant: height),

                arrowView.bottomAnchor.constraint(equalTo: tooltipView.topAnchor),
                arrowView.centerXAnchor.constraint(equalTo: tooltipView.centerXAnchor),
                arrowView.widthAnchor.constraint(equalToConstant: arrowSize.width),
                arrowView.heightAnchor.constraint(equalToConstant: arrowSize.height)
            ])

        case "left":
            NSLayoutConstraint.activate([
                tooltipView.bottomAnchor.constraint(equalTo: dimView.topAnchor, constant: highlightFrame.minY - arrowSize.height - paddingTop),
                tooltipView.centerXAnchor.constraint(equalTo: dimView.leadingAnchor, constant: highlightFrame.midX + paddingLeft),
                tooltipView.widthAnchor.constraint(equalToConstant: width),
                tooltipView.heightAnchor.constraint(equalToConstant: height),

                arrowView.topAnchor.constraint(equalTo: tooltipView.bottomAnchor),
                arrowView.centerXAnchor.constraint(equalTo: tooltipView.centerXAnchor),
                arrowView.widthAnchor.constraint(equalToConstant: arrowSize.width),
                arrowView.heightAnchor.constraint(equalToConstant: arrowSize.height)
            ])

        case "right":
            NSLayoutConstraint.activate([
                tooltipView.centerYAnchor.constraint(equalTo: dimView.topAnchor, constant: highlightFrame.midY + paddingTop),
                tooltipView.leadingAnchor.constraint(equalTo: dimView.leadingAnchor, constant: highlightFrame.maxX + arrowSize.width + paddingLeft),
                tooltipView.widthAnchor.constraint(equalToConstant: width),
                tooltipView.heightAnchor.constraint(equalToConstant: height),

                arrowView.centerYAnchor.constraint(equalTo: tooltipView.centerYAnchor),
                arrowView.trailingAnchor.constraint(equalTo: tooltipView.leadingAnchor),
                arrowView.widthAnchor.constraint(equalToConstant: arrowSize.width),
                arrowView.heightAnchor.constraint(equalToConstant: arrowSize.height)
            ])

        default:
            NSLayoutConstraint.activate([
                tooltipView.bottomAnchor.constraint(equalTo: dimView.topAnchor, constant: highlightFrame.minY - arrowSize.height - paddingTop),
                tooltipView.centerXAnchor.constraint(equalTo: dimView.leadingAnchor, constant: highlightFrame.midX + paddingLeft),
                tooltipView.widthAnchor.constraint(equalToConstant: width),
                tooltipView.heightAnchor.constraint(equalToConstant: height),

                arrowView.topAnchor.constraint(equalTo: tooltipView.bottomAnchor),
                arrowView.centerXAnchor.constraint(equalTo: tooltipView.centerXAnchor),
                arrowView.widthAnchor.constraint(equalToConstant: arrowSize.width),
                arrowView.heightAnchor.constraint(equalToConstant: arrowSize.height)
            ])
        }


        dimView.alpha = 0
        UIView.animate(withDuration: 0.25) {
            dimView.alpha = 1.0
        }
        let tapGesture = UITapGestureRecognizer(target: ClosureSleeve {
            UIView.animate(withDuration: 0.3, animations: {
                tooltipView.alpha = 0
                arrowView.alpha = 0
                dimView.alpha = 0
            }) { _ in
                dimView.removeFromSuperview()
                completion()
            }
        })
        dimView.addGestureRecognizer(tapGesture)

    }

    @MainActor
    static func findView(in root: UIView, withAccessibilityIdentifier identifier: String) -> UIView? {
        if root.accessibilityIdentifier == identifier {
            return root
        }
        for subview in root.subviews {
            if let found = findView(in: subview, withAccessibilityIdentifier: identifier) {
                return found
            }
        }

        return nil
    }
}


extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        } else {
            print("⚠️ Failed to convert string to data: \(string)")
        }
    }
}


extension UIAnalyzer {
    private static var shownTooltipIds = Set<String>()
    private static let shownTooltipsKey = "ShownTooltipIds"
    private static func loadShownTooltips() {
        if let savedIds = UserDefaults.standard.array(forKey: shownTooltipsKey) as? [String] {
            shownTooltipIds = Set(savedIds)
        }
    }

    private static func saveShownTooltips() {
        UserDefaults.standard.set(Array(shownTooltipIds), forKey: shownTooltipsKey)
    }
    
    func showTooltipsSequentially(from campaigns: [CampaignModel]) {
        UIAnalyzer.loadShownTooltips()
        
        var allTooltips: [Tooltip] = []

        for campaign in campaigns {
            if case let .toolTip(details) = campaign.details,
               let tooltips = details.tooltips {
                let newTooltips = tooltips.filter { tooltip in
                    let tooltipId = generateTooltipId(for: tooltip)
                    return !UIAnalyzer.shownTooltipIds.contains(tooltipId)
                }
                allTooltips.append(contentsOf: newTooltips)
            }
        }
        guard !allTooltips.isEmpty else {
            print("No new tooltips to show")
            return
        }

        showNextTooltip(from: allTooltips, index: 0)
    }

    func showNextTooltip(from tooltips: [Tooltip], index: Int) {
        guard index < tooltips.count else { return }
        let tooltip = tooltips[index]
        let id = tooltip.target
        let tooltipId = generateTooltipId(for: tooltip)

        UIAnalyzer.showTooltip(forID: id, frame: nil, tooltip: tooltip) {
            UIAnalyzer.shownTooltipIds.insert(tooltipId)
            UIAnalyzer.saveShownTooltips()
            self.showNextTooltip(from: tooltips, index: index + 1)
        }
    }
    
    private func generateTooltipId(for tooltip: Tooltip) -> String {
        let components = [
            tooltip.target ?? "",
            tooltip.position ?? "",
            tooltip.type ?? "",
            tooltip.link ?? "",
            tooltip.url ?? ""
        ].joined(separator: "_")
        
        return components.isEmpty ? UUID().uuidString : components
    }
    
    static func resetShownTooltips() {
        shownTooltipIds.removeAll()
        UserDefaults.standard.removeObject(forKey: shownTooltipsKey)
        print("All tooltip tracking has been reset")
    }
    
    func hasTooltipBeenShown(_ tooltip: Tooltip) -> Bool {
        UIAnalyzer.loadShownTooltips()
        let tooltipId = generateTooltipId(for: tooltip)
        return UIAnalyzer.shownTooltipIds.contains(tooltipId)
    }
}

