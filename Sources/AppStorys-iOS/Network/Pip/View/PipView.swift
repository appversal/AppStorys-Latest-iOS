//
//  File.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 28/02/25.
//


import SwiftUI
import AVKit

public class AVPlayerManager: ObservableObject {
    @Published var player = AVPlayer()

    func updateVideoURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid video URL")
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

public struct FloatingPiPView: View {
    @State private var isMuted = false
    @State private var isVisible = true
    @State private var position = CGSize.zero
    @State private var isExpanded = false
    @State private var showFullScreen = false
    @StateObject private var playerManager = AVPlayerManager()
    @StateObject private var apiService = AppStorys()
    
    let appID: String
        let accountID: String
        let screenName: String
        let positionID: String
    
    public init(appID: String, accountID: String, screenName: String, position: String) {
        self.appID = appID
        self.accountID = accountID
        self.screenName = screenName
        self.positionID = position
       
    }


    var pipCampaign: PipCampaign? {
        apiService.pipCampaigns.first
    }

    public var body: some View {
        if isVisible {
            if let campaign = pipCampaign, let videoURL = campaign.details?.first?.smallVideo {
                let videoWidth = CGFloat(campaign.details?.first?.width ?? 230)
                let videoHeight = CGFloat(campaign.details?.first?.height ?? 405)
                
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
                                            let minX = -screenWidth / 2 + halfWidth
                                            let maxX = screenWidth / 2 - halfWidth
                                            let minY = -screenHeight / 2 + halfHeight
                                            let maxY = screenHeight / 2 - halfHeight
                                            
                                            position.width = max(minX, min(maxX, gesture.translation.width))
                                            position.height = max(minY, min(maxY, gesture.translation.height))
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    // Smoothly animate the final position if necessary
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)) {
                                        // Ensure the PiP stays within screen bounds
                                    }
                                }
                        )
                        .onAppear {
                            print("🟢 FloatingPiPView appeared")
                            print("🔗 Video URL: \(videoURL)")
                            
                            playerManager.updateVideoURL(videoURL)
                            playerManager.play()
                            trackAction(campaignID: campaign.id, actionType: .view)
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
                                isVisible = true  // Bring back PiP mode
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
                        
                        if isExpanded, let linkString = campaign.details?.first?.link, let link = URL(string: linkString) {
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
//                    apiService.validateAccount(appID: appID, accountID: accountID)
//                    apiService.trackScreen(screenName: "Home Screen", position: "1")
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
                        appID: appID,
                        accountID: accountID,
                        screenName: screenName,
                        position: positionID,
                        isVisible: $showFullScreen, isPipVisible: $isVisible
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
//                        apiService.validateAccount(appID: appID, accountID: accountID)
//                        apiService.trackScreen(screenName: "Home Screen", position: "1")
                    }
            }
        }
    }
    
    func trackAction(campaignID: String, actionType: ActionType) {
        guard let accessToken = apiService.accessToken else {
            print("Access Token is missing.")
            return
        }
        Task {
            do {
                print("Action tracked: \(actionType.rawValue) for campaign \(campaignID)")
            } catch {
                print("Error tracking action: \(error)")
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

#Preview {
    FloatingPiPView(
        appID: "afadf960-3975-4ba2-933b-fac71ccc2002",
        accountID: "13555479-077f-445e-87f0-e6eae2e215c5",
        screenName: "Home Screen",
        position: "1"
    )
}
