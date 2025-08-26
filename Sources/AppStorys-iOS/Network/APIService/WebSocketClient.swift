//
//  WebSocketClient.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 10/07/25.
//
import Foundation
import Combine

// MARK: - Models

struct TrackUserWebSocketRequest: Codable {
    let user_id: String
    let attributes: [String: AnyCodable]
    let screenName: String?
    let silentUpdate: Bool?
}

struct WebSocketConnectionResponse: Codable {
    let mqtt: MQTTConfig
    let userID: String
    let ws: WebSocketConfig
}

struct MQTTConfig: Codable {
    let broker: String
    let clientID: String
    let topic: String
}

struct WebSocketConfig: Codable {
    let expires: Int
    let sessionID: String
    let token: String
    let url: String
}



// MARK: - WebSocket Client

@MainActor
public class WebSocketClient {
    public var webSocketTask: URLSessionWebSocketTask?
    public var isConnected = false
    
    // ✅ New: a callback/closure for incoming campaign responses
    public var onCampaignResponse: ((CampaignResponse) -> Void)?
    public var onDisconnect: (() -> Void)?
    
    func connect(with config: WebSocketConfig) {
            guard let url = URL(string: config.url) else { return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.sessionID, forHTTPHeaderField: "Session-ID")
            
            let session = URLSession(configuration: .default)
            webSocketTask = session.webSocketTask(with: request)
            webSocketTask?.resume()
            isConnected = true
            print("✅ WebSocket connected to \(config.url)")
            listen()
        }
    
    private func listen() {
        print("👂 [WebSocket] Waiting for next message...")
        
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("❌ [WebSocket] Error receiving message: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.isConnected = false
                }

            case .success(let message):
                switch message {
                case .string(let text):
                    print("📨 [WebSocket] String message received: \(text)")
                    guard let self = self else { return }

                    if let data = text.data(using: .utf8) {
                        do {
                            let response = try JSONDecoder().decode(CampaignResponse.self, from: data)
                            print("✅ [WebSocket] Successfully decoded CampaignResponse: \(response)")
                            Task { @MainActor in
                                self.onCampaignResponse?(response)
                            }
                        } catch {
                            print("❌ [WebSocket] Failed to decode CampaignResponse: \(error)")
                            if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                                print("🔍 [WebSocket] Raw JSON received (not matching model): \(json)")
                            }
                        }
                    }

                case .data(let data):
                    print("📨 [WebSocket] Binary message received (\(data.count) bytes)")
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                        print("🔍 [WebSocket] Decoded binary JSON: \(json)")
                    }

                @unknown default:
                    print("⚠️ [WebSocket] Received unknown message type")
                }

                // Continue listening
                Task { @MainActor in
                    self?.listen()
                }
            }
        }
    }


    func disconnect() {
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            Task { @MainActor in
                isConnected = false
                onDisconnect?()
            }
        }
    func isConnectedNow() -> Bool {
        return isConnected
    }
}
