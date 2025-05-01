//
//  FullScreenPipView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.
//

import SwiftUI
import AVKit

public struct FullScreenPipView : View {
    @State private var isMuted = false
    @State private var position = CGSize.zero
    @StateObject private var playerManager = AVPlayerManager()
    @Binding var isVisible: Bool
    @ObservedObject private var apiService: AppStorys
    @Binding var isPipVisible: Bool
    
    public init(isVisible: Binding<Bool>, isPipVisible: Binding<Bool>, apiService: AppStorys) {
        self._isVisible = isVisible
        self._isPipVisible = isPipVisible
        self.apiService = apiService
    }
    
    public var body: some View {
        if isVisible {
            if let pipCampaign = apiService.pipCampaigns.first {
                if case let .pip(details) = pipCampaign.details,
                   let videoURL = details.smallVideo {
                    let videoWidth = CGFloat(details.width ?? 230)
                    let videoHeight = CGFloat(details.height ?? 405)
                    
                    ZStack(alignment: .top) {
                        Color.black.ignoresSafeArea()
                        CustomAVPlayerView(player: playerManager.player)
                            .padding(.top,60)
                            .padding(.bottom,60)

                            .edgesIgnoringSafeArea(.all)
                            .onAppear {
                                playerManager.updateVideoURL(videoURL)
                                playerManager.play()
                            }
                        VStack {
                            HStack {
                                Button(action: {
                                    isMuted.toggle()
                                    playerManager.player.isMuted = isMuted
                                }) {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .padding(5)
                                }
                                .frame(width: 35, height: 35)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                
                                Button(action: {
                                    isVisible = false
                                    playerManager.player.pause()
                                }) {
                                    Image(systemName: "arrow.down.forward.and.arrow.up.backward.rectangle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .padding(5)
                                }
                                .frame(width: 35, height: 35)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                
                                Spacer()
                                
                                Button(action: {
                                    isVisible = false
                                    isPipVisible = false
                                    playerManager.player.pause()
                                }) {
                                    Image(systemName: "xmark.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .padding(5)
                                }
                                .frame(width: 35, height: 35)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 50)
                            Spacer()
                            if let linkString = details.link, let link = URL(string: linkString) {
                                Button(action: {
                                    trackAction(campaignID: pipCampaign.id, actionType: .click)
                                    UIApplication.shared.open(link)
                                }) {
                                    Text("Click")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white)
                                        .foregroundColor(.black)
                                        .cornerRadius(10)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 70)
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    }
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .transition(.move(edge: .trailing))
                    
                } else {
                    ProgressView("Loading...")
                        .padding()
                }
            }
        }
    }
    
    func trackAction(campaignID: String, actionType: ActionType) {
        guard let accessToken = apiService.accessToken else {
            return
        }
    }
}
