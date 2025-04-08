//
//  PipView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.
//

import SwiftUI
import AVKit

public class AVPlayerManager: ObservableObject {
    @Published var player = AVPlayer()

    func updateVideoURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        let playerItem = AVPlayerItem(url: url)
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
    }

    @MainActor func play() {
        player.play()
    }
}

public struct PipView: View {
    @State private var isMuted = false
    @State private var isVisible = true
    @State private var position = CGSize.zero
    @State private var isExpanded = false
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
                            .frame(width: isExpanded ? UIScreen.main.bounds.width : videoWidth,
                                   height: isExpanded ? UIScreen.main.bounds.height : videoHeight)
                            .cornerRadius(15)
                            .shadow(radius: 5)
                            .offset(x: isExpanded ? 0 : position.width, y: isExpanded ? 0 : position.height)
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        if !isExpanded {
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
                                    }

                                    .onEnded { _ in
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)) {
                                        }
                                    }
                            )
                            .onAppear {
                                
                                playerManager.updateVideoURL(videoURL)
                                playerManager.play()
                                Task {
                                    await apiService.trackAction(type: .view, campaignID: pipCampaign.id, widgetID: "")
                                }
                            }
                        
                            .edgesIgnoringSafeArea(isExpanded ? .all : [])
                        
                        VStack (alignment:.leading){
                            HStack {
                                Button(action: {
                                    isMuted.toggle()
                                    playerManager.player.isMuted = isMuted
                                }) {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: isExpanded ? 20 : 12, height: isExpanded ? 20 : 12)
                                        .padding(isExpanded ? 10 : 4)
                                }
                                .frame(width: isExpanded ? 40 : 20, height: isExpanded ? 40 : 20)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .padding(.leading, isExpanded ? 10 : 5)
                                .padding(.top, isExpanded ? -5 : -15)
                                
                                Spacer()
                                
                                Button(action: {
                                    
                                    isVisible = false
                                    playerManager.player.pause()
                                }) {
                                    Image(systemName: "xmark")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: isExpanded ? 20 : 12, height: isExpanded ? 20 : 12)
                                        .padding(isExpanded ? 10 : 4)
                                }
                                
                                .frame(width: isExpanded ? 40 : 20, height: isExpanded ? 40 : 20)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .padding(.trailing, isExpanded ? 10 : 5)
                                .padding(.top, isExpanded ? -5 : -15)
                            }
                            .frame(alignment: .top)
                            
                        }
                        .padding(.bottom, isExpanded ? UIScreen.main.bounds.height - 50 : videoHeight-40)
                        .frame(width: isExpanded ? UIScreen.main.bounds.width : videoWidth, height: isExpanded ? UIScreen.main.bounds.height : videoHeight)
                        .offset(x: isExpanded ? 0 : position.width, y: isExpanded ? 0 : position.height)
                        
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: { if showFullScreen {
                                    showFullScreen = false
                                    isVisible = true
                                } else {
                                    showFullScreen = true
                                }}) {
                                    Image(systemName: "rectangle.expand.vertical")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: isExpanded ? 20 : 12, height: isExpanded ? 20 : 12)
                                        .padding(isExpanded ? 10 : 4)
                                        .foregroundStyle(Color.white)
                                        .background(Color.black)
                                        .clipShape(Circle())
                                }
                                .frame(width: isExpanded ? 40 : 20, height: isExpanded ? 40 : 20)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .padding(.trailing, isExpanded ? 10 : 5)
                                .padding(.bottom, isExpanded ? 25 : 0)
                            }
                        }
                        .padding(.top, isExpanded ? UIScreen.main.bounds.height - 120 : videoHeight-40)
                        .offset(x: isExpanded ? 0 : position.width, y: isExpanded ? 0 : position.height)
                        .frame(width: isExpanded ? UIScreen.main.bounds.width : videoWidth, height: isExpanded ? UIScreen.main.bounds.height : videoHeight)
                        
                        VStack {
                            Spacer()
                            
                            if isExpanded, let linkString = details.link, let link = URL(string: linkString) {
                                Button(action: {
                                    UIApplication.shared.open(link)
                                    
                                }) {
                                    Text("Click")
                                        .font(.headline)
                                        .frame(width: 180)
                                        .padding()
                                        .background(Color.white)
                                        .foregroundColor(.black)
                                        .cornerRadius(10)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 50)
                            }
                        }
                        .frame(width: isExpanded ? UIScreen.main.bounds.width : videoWidth,
                               height: isExpanded ? UIScreen.main.bounds.height : videoHeight)
                        
                    }
                    .onAppear {
                    }
                    .frame(width: isExpanded ? UIScreen.main.bounds.width : videoWidth,
                           height: isExpanded ? UIScreen.main.bounds.height : videoHeight)
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
                        .onAppear {
                        }
                }
            }
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
