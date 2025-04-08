//
//  PipViewFinal.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.
//
import SwiftUI
import AVKit
import Combine

struct PipVideo: View {
    // MARK: - Properties
    let height: CGFloat
    let width: CGFloat
    let videoUri: String
    let fullScreenVideoUri: String
    let buttonText: String
    let position: String?
    let link: String
    let onClose: () -> Void
    let onButtonClick: () -> Void
    let onExpandClick: () -> Void
    
    // MARK: - State
    @State private var pipSize: CGSize = .zero
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    @State private var isInitialized: Bool = false
    @State private var isFullScreen: Bool = false
    @State private var isMuted: Bool = true
    
    // MARK: - Environment
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    
    // MARK: - Player
    @StateObject private var playerManager = PlayerManager()
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Only show PiP when initialized
                if isInitialized {
                    pipView
                        .frame(width: width, height: height)
                        .position(
                            x: offsetX + width/2,
                            y: offsetY + height/2
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let boundaryPadding: CGFloat = 12
                                    
                                    // Calculate new position
                                    var newX = offsetX + value.translation.width
                                    var newY = offsetY + value.translation.height
                                    
                                    // Apply boundaries
                                    newX = max(boundaryPadding, min(newX, geometry.size.width - width - boundaryPadding))
                                    newY = max(boundaryPadding, min(newY, geometry.size.height - height - boundaryPadding))
                                    
                                    offsetX = newX
                                    offsetY = newY
                                }
                        )
                } else {
                    // Invisible box to measure and set initial position
                    Color.clear
                        .frame(width: width, height: height)
                        .onAppear {
                            pipSize = CGSize(width: width, height: height)
                            
                            // Set initial position based on parameter
                            let boundaryPadding: CGFloat = 12
                            
                            if position == "left" {
                                // Bottom left
                                offsetX = boundaryPadding
                            } else {
                                // Bottom right (default)
                                offsetX = geometry.size.width - width - boundaryPadding
                            }
                            
                            // Y position is always bottom
                            offsetY = geometry.size.height - height - boundaryPadding
                            
                            // Mark as initialized
                            isInitialized = true
                            
                            // Setup player
                            playerManager.setupPipPlayer(videoUri: videoUri)
                            playerManager.isMuted = isMuted
                        }
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    playerManager.pipPlayer?.play()
                } else if newPhase == .background {
                    playerManager.pipPlayer?.pause()
                }
            }
            .onChange(of: isMuted) { newValue in
                playerManager.isMuted = newValue
            }
            .onChange(of: isFullScreen) { newValue in
                if newValue {
                    playerManager.pipPlayer?.pause()
                } else {
                    playerManager.pipPlayer?.play()
                }
            }
            .fullScreenCover(isPresented: $isFullScreen) {
                FullScreenVideoView(
                    videoUri: fullScreenVideoUri,
                    buttonText: buttonText,
                    link: link,
                    onDismiss: {
                        isFullScreen = false
                        playerManager.pipPlayer?.play()
                    },
                    onClose: onClose,
                    onButtonClick: onButtonClick
                )
            }
        }
    }
    
    // MARK: - PiP View
    private var pipView: some View {
        ZStack {
            // Video Player
            PipPlayerView(player: playerManager.pipPlayer)
                .onTapGesture {
                    onExpandClick()
                    isFullScreen = true
                    playerManager.pipPlayer?.pause()
                }
            
            // Close Button (Top-Right)
            VStack {
                HStack {
                    // Mute Button (Top-Left)
                    Button(action: {
                        isMuted.toggle()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(4)
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 23, height: 23)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(4)
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Maximize Button (Bottom-Right)
                    Button(action: {
                        onExpandClick()
                        isFullScreen = true
                        playerManager.pipPlayer?.pause()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(4)
                }
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6)
    }
}

// MARK: - Player Manager
class PlayerManager: ObservableObject {
    var pipPlayer: AVPlayer?
    var cancellables = Set<AnyCancellable>()
    
    @Published var isMuted: Bool = true {
        didSet {
            pipPlayer?.isMuted = isMuted
        }
    }
    
    @MainActor func setupPipPlayer(videoUri: String) {
        guard let url = URL(string: videoUri) else { return }
        
        pipPlayer = AVPlayer(url: url)
        pipPlayer?.actionAtItemEnd = .none
        pipPlayer?.isMuted = isMuted
        
        // Loop video
        NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.restartVideo()
            }
            .store(in: &cancellables)
        
        pipPlayer?.play()
    }
    
    @MainActor private func restartVideo() {
        pipPlayer?.seek(to: .zero)
        pipPlayer?.play()
    }
    
    deinit {
        Task.detached { @MainActor [pipPlayer] in
            pipPlayer?.pause()
        }
    }




}

// MARK: - PiP Player View
struct PipPlayerView: UIViewRepresentable {
    let player: AVPlayer?
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

// MARK: - Custom UIView for AVPlayer
class PlayerUIView: UIView {
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

// MARK: - Fullscreen Video View
struct FullScreenVideoView: View {
    // MARK: - Properties
    let videoUri: String
    let buttonText: String?
    let link: String?
    let onDismiss: () -> Void
    let onClose: () -> Void
    let onButtonClick: () -> Void
    
    // MARK: - State
    @Environment(\.presentationMode) var presentationMode
    @State private var player: AVPlayer?
    @State private var isMuted: Bool = false
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let player = player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Controls overlay
            VStack {
                HStack {
                    // Minimize button
                    Button(action: {
                        onDismiss()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(16)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Mute Button
                        Button(action: {
                            isMuted.toggle()
                            player?.isMuted = isMuted
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Close Button
                        Button(action: onClose) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(16)
                }
                
                Spacer()
                
                // Bottom button
                if let buttonText = buttonText, !buttonText.isEmpty,
                   let link = link, !link.isEmpty {
                    Button(action: {
                        if let url = URL(string: link) {
                            UIApplication.shared.open(url)
                        }
                        onButtonClick()
                    }) {
                        Text(buttonText)
                            .foregroundColor(.black)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                            )
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    // MARK: - Setup Player
    private func setupPlayer() {
        guard let url = URL(string: videoUri) else { return }
        
        player = AVPlayer(url: url)
        player?.isMuted = isMuted
        player?.actionAtItemEnd = .none
        
NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [self] _ in
    Task { @MainActor in
        player?.seek(to: .zero)
        player?.play()
    }
}

player?.play()
}


}

// MARK: - Preview

// MARK: - Preview
struct PipVideo_Previews: PreviewProvider {
static var previews: some View {
PipVideo(
    height: 200,
    width: 150,
    videoUri: "https://example.com/video.mp4",
    fullScreenVideoUri: "https://example.com/video.mp4",
    buttonText: "Learn More",
    position: "right",
    link: "https://example.com",
    onClose: {},
    onButtonClick: {},
    onExpandClick: {}
)
}
}
