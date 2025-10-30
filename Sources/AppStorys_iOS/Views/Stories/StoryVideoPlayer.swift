//
//  StoryVideoPlayer.swift
//  AppStorys_iOS
//
//  Fixed: Added mute parameter + improved video reset logic
//

import SwiftUI
import AVKit
import Combine

/// Video player for story slides with pause/reset/mute support
struct StoryVideoPlayer: UIViewControllerRepresentable {
    let url: URL
    let onReady: () -> Void
    let onEnd: () -> Void
    let isActive: Bool
    let isPaused: Bool
    let isMuted: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        
        let player = AVPlayer(url: url)
        player.isMuted = isMuted
        player.preventsDisplaySleepDuringVideoPlayback = true
        
        controller.player = player
        context.coordinator.player = player
        context.coordinator.observePlayer(player)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        guard let player = uiViewController.player else { return }
        
        // ✅ Update mute state
        if player.isMuted != isMuted {
            player.isMuted = isMuted
            Logger.debug("🔊 Video mute: \(isMuted)")
        }
        
        // ✅ CRITICAL: Detect when we become active again after being inactive
        let wasInactive = !context.coordinator.wasActive
        let isNowActive = isActive
        
        if wasInactive && isNowActive {
            // ✅ Reset video to beginning when returning to this story
            player.seek(to: .zero)
            Logger.debug("🔄 Video reset to beginning")
        }
        
        // Update tracking state
        context.coordinator.wasActive = isActive
        
        // Update playback state
        context.coordinator.updatePlaybackState(
            isActive: isActive,
            isPaused: isPaused,
            player: player
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onReady: onReady, onEnd: onEnd)
    }
    
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        Logger.debug("🗑️ Dismantling video player")
        coordinator.cleanup()
    }
    
    class Coordinator: NSObject {
        let onReady: () -> Void
        let onEnd: () -> Void
        var isReadyToPlay = false
        var player: AVPlayer?
        var wasActive = true  // ✅ Track previous active state
        private var observations: [NSKeyValueObservation] = []
        private var notificationToken: NSObjectProtocol?
        
        init(onReady: @escaping () -> Void, onEnd: @escaping () -> Void) {
            self.onReady = onReady
            self.onEnd = onEnd
        }
        
        func updatePlaybackState(isActive: Bool, isPaused: Bool, player: AVPlayer) {
            let shouldPlay = isActive && !isPaused && isReadyToPlay
            let isCurrentlyPlaying = player.rate > 0
            
            if shouldPlay && !isCurrentlyPlaying {
                player.play()
                Logger.debug("▶️ Video playing (active: \(isActive), paused: \(isPaused))")
            } else if !shouldPlay && isCurrentlyPlaying {
                player.pause()
                Logger.debug("⏸️ Video paused (active: \(isActive), paused: \(isPaused))")
            }
        }
        
        func observePlayer(_ player: AVPlayer) {
            // Observe ready state
            let statusObservation = player.observe(\.status, options: [.new]) { [weak self] player, _ in
                guard let self = self else { return }
                
                if player.status == .readyToPlay {
                    self.isReadyToPlay = true
                    DispatchQueue.main.async {
                        self.onReady()
                    }
                } else if player.status == .failed {
                    Logger.error("❌ Video player failed to load")
                }
            }
            observations.append(statusObservation)
            
            // Observe end of video
            notificationToken = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.onEnd()
            }
        }
        
        func cleanup() {
            observations.forEach { $0.invalidate() }
            observations.removeAll()
            
            if let token = notificationToken {
                NotificationCenter.default.removeObserver(token)
                notificationToken = nil
            }
            
            player?.pause()
            player = nil
            isReadyToPlay = false
            wasActive = true  // Reset tracking
        }
        
        deinit {
            cleanup()
        }
    }
}

/// Player manager to control video playback state
@MainActor
class StoryVideoPlayerManager: ObservableObject {
    @Published var isPlaying: Bool = false
    
    func play() {
        isPlaying = true
    }
    
    func pause() {
        isPlaying = false
    }
}
