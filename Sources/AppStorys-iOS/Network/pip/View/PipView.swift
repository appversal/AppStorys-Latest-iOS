//
//  PipView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.
//

import SwiftUI
import AVKit

@MainActor
public class AVPlayerManager: ObservableObject {
    @Published var player = AVPlayer()
    private let cacheManager = VideoCacheManager.shared

    func updateVideoURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        let videoURL = cacheManager.cachedURLForVideo(originalURL: url)
        
        let playerItem = AVPlayerItem(url: videoURL)
        player.replaceCurrentItem(with: playerItem)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.player.seek(to: .zero)
                self?.player.play()
            }
        }
        if !cacheManager.isVideoCached(url: url) {
            cacheManager.cacheVideo(url: url)
        }
    }

    @MainActor func play() {
        player.play()
    }
    
    func prefetchVideos(urls: [URL]) {
        cacheManager.prefetchVideos(urls: urls)
    }
}

public struct PipView: View {
    @State private var isMuted = false
    @State private var isVisible = true
    @State private var position = CGSize.zero
    @State private var showFullScreen = false
    @StateObject private var playerManager = AVPlayerManager()
    @ObservedObject private var apiService: AppStorys
    
    public init(apiService: AppStorys) {
        self.apiService = apiService
    }

    public var body: some View {
        if isVisible {
            if let pipCampaign = apiService.pipCampaigns.first {
                if case let .pip(details) = pipCampaign.details,
                   let videoURL = details.smallVideo {
                    let videoWidth = CGFloat(details.width ?? 230)
                    let videoHeight = CGFloat(details.height ?? 405)
                    
                    ZStack {
                        CustomAVPlayerView(player: playerManager.player)
                            .frame(width: videoWidth, height: videoHeight)
                            .cornerRadius(15)
                            .shadow(radius: 5)
                            .offset(x: position.width, y: position.height)
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)) {
                                            let screenWidth = UIScreen.main.bounds.width - 20
                                            let screenHeight = UIScreen.main.bounds.height - 20
                                            let halfWidth = videoWidth / 2
                                            let halfHeight = videoHeight / 2
                                            
                                            let safeAreaInsets = UIApplication.shared.windows.first?.safeAreaInsets ?? UIEdgeInsets()
                                            let topSafeArea = safeAreaInsets.top
                                            let bottomSafeArea = safeAreaInsets.bottom
                                            
                                            let minX = -screenWidth / 2 + halfWidth
                                            let maxX = screenWidth / 2 - halfWidth
                                            let minY = (-screenHeight / 2 + halfHeight) + topSafeArea
                                            let maxY = (screenHeight / 2 - halfHeight) - bottomSafeArea
                                            
                                            position.width = max(minX, min(maxX, gesture.translation.width))
                                            position.height = max(minY, min(maxY, gesture.translation.height))
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)) {
                                        }
                                    }
                            )
                            .onTapGesture {
                                showFullScreen = true
                            }
                            .onAppear {
                                if position == .zero {
                                    let screenWidth = UIScreen.main.bounds.width
                                    let screenHeight = UIScreen.main.bounds.height
                                    let safeArea = UIApplication.shared.windows.first?.safeAreaInsets ?? .zero
                                    let horizontalOffset = screenWidth / 2 - videoWidth / 2 - 10
                                    let verticalOffset = screenHeight / 2 - videoHeight / 2 - safeArea.bottom - 20
                                    
                                    if let backendPosition = details.position?.lowercased() {
                                        switch backendPosition {
                                        case "right":
                                            position = CGSize(width: horizontalOffset, height: verticalOffset)
                                        case "left":
                                            position = CGSize(width: -horizontalOffset, height: verticalOffset)
                                        default:
                                            position = CGSize(width: horizontalOffset, height: verticalOffset)
                                        }
                                    }
                                }
                                playerManager.updateVideoURL(videoURL)
                                playerManager.play()
                                prefetchOtherCampaignVideos(currentURL: videoURL)
                                
                                Task {
                                    await apiService.trackAction(type: .view, campaignID: pipCampaign.id, widgetID: "")
                                }
                            }
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Button(action: {
                                    isMuted.toggle()
                                    playerManager.player.isMuted = isMuted
                                }) {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                        .padding(4)
                                }
                                .frame(width: 20, height: 20)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .padding(.leading, 5)
                                .padding(.top, -15)
                                
                                Spacer()
                                
                                Button(action: {
                                    isVisible = false
                                    playerManager.player.pause()
                                }) {
                                    Image(systemName: "xmark")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                        .padding(4)
                                }
                                .frame(width: 20, height: 20)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .padding(.trailing, 5)
                                .padding(.top, -15)
                            }
                            .frame(alignment: .top)
                        }
                        .padding(.bottom, videoHeight - 40)
                        .frame(width: videoWidth, height: videoHeight)
                        .offset(x: position.width, y: position.height)
                        
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    if showFullScreen {
                                        showFullScreen = false
                                        isVisible = true
                                    } else {
                                        showFullScreen = true
                                    }
                                }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right.rectangle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                        .padding(4)
                                        .foregroundStyle(Color.white)
                                        .background(Color.black)
                                        .clipShape(Circle())
                                }
                                .frame(width: 20, height: 20)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .padding(.trailing, 5)
                            }
                        }
                        .padding(.top, videoHeight - 40)
                        .offset(x: position.width, y: position.height)
                        .frame(width: videoWidth, height: videoHeight)
                    }
                    .frame(width: videoWidth, height: videoHeight)
                    .animation(.easeInOut, value: isVisible)
                    .fullScreenCover(isPresented: $showFullScreen, onDismiss: {
                        isVisible = true
                        isMuted = false
                        playerManager.player.isMuted = false
                    }) {
                        FullScreenPipView(
                            isVisible: $showFullScreen, isPipVisible: $isVisible, apiService: apiService
                        )
                    }
                    .onChange(of: showFullScreen) { newValue in
                        if newValue {
                            isMuted = true
                            playerManager.player.isMuted = true
                        }
                    }
                } else {
                    ProgressView("Loading...")
                        .padding()
                }
            }
        }
    }
    
    private func prefetchOtherCampaignVideos(currentURL: String) {
        var videosToCache: [URL] = []
        
        for campaign in apiService.pipCampaigns {
            if case let .pip(details) = campaign.details {
                if let smallVideoStr = details.smallVideo, smallVideoStr != currentURL,
                   let smallVideoURL = URL(string: smallVideoStr) {
                    videosToCache.append(smallVideoURL)
                }
                if let fullScreenVideoStr = details.largeVideo
                    ,
                   let fullScreenURL = URL(string: fullScreenVideoStr) {
                    videosToCache.append(fullScreenURL)
                }
            }
        }
        if !videosToCache.isEmpty {
            playerManager.prefetchVideos(urls: videosToCache)
        }
    }
}

struct CustomAVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                player.seek(to: .zero)
                player.play()
            }
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.showsPlaybackControls = false
    }
}
