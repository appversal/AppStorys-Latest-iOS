//
//  PIPPlayerManager.swift
//  AppStorys_iOS
//
//  SIMPLIFIED - Let ARC handle cleanup
//

import AVKit
import Combine

@MainActor
public class PIPPlayerManager: ObservableObject {
    // MARK: - Published Properties
    @Published public var player = AVPlayer()
    
    // MARK: - Private Properties
    private var loopObserver: NSObjectProtocol?
    private var currentVideoURL: String?
    
    // MARK: - Initialization
    public init() {
        setupAudioSession()
    }
    
    // MARK: - Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.error("❌ Failed to setup audio session", error: error)
        }
    }
    
    // MARK: - Video Control
    public func updateVideoURL(_ urlString: String) {
        guard urlString != currentVideoURL else {
            Logger.debug("⏭️ Same video URL, skipping reload")
            return
        }
        
        guard let url = URL(string: urlString) else {
            Logger.error("❌ Invalid video URL: \(urlString)")
            return
        }
        
        currentVideoURL = urlString
        Logger.debug("🎬 Loading video: \(url.absoluteString)")
        
        // Clean up old observer
        removeLoopObserver()
        
        // Load new video
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        
        // Setup looping
        setupLooping(for: playerItem)
    }
    
    private func setupLooping(for playerItem: AVPlayerItem) {
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.player.seek(to: .zero)
                self?.player.play()
            }
        }
    }
    
    public func play() {
        player.play()
        Logger.debug("▶️ Video playing")
    }
    
    public func pause() {
        player.pause()
        Logger.debug("⏸️ Video paused")
    }
    
    // MARK: - Cleanup
    
    /// Public cleanup method - call this explicitly when done with the player
    public func cleanup() {
        Logger.debug("🧹 Cleaning up player")
        removeLoopObserver()
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentVideoURL = nil
    }
    
    private func removeLoopObserver() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
    }
}
