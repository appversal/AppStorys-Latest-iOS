//
//  FullScreenPipView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.
//

import SwiftUI
import AVKit

struct FullScreenPipView: View {
    @State private var isMuted = false
    @StateObject private var playerManager = AVPlayerManager()
    @ObservedObject private var apiService: AppStorys
    private let hideFullScreenCallback: () -> Void
    
    init(apiService: AppStorys, hideFullScreenCallback: @escaping () -> Void) {
        self.apiService = apiService
        self.hideFullScreenCallback = hideFullScreenCallback
    }
    
    var body: some View {
        if let pipCampaign = apiService.pipCampaigns.first {
            if case let .pip(details) = pipCampaign.details {
                ZStack(alignment: .top) {
                    Color.black.ignoresSafeArea()
                    CustomAVPlayerView(player: playerManager.player)
                        .padding(.top, 60)
                        .padding(.bottom, 60)
                        .edgesIgnoringSafeArea(.all)
                        .onAppear {
                            // Use large video for full-screen, fallback to small video
                            let videoURL = details.largeVideo ?? details.smallVideo ?? ""
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
                                playerManager.player.pause()
                                hideFullScreenCallback()
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
                                apiService.hidePipOverlay()
                                UserDefaults.standard.set(true, forKey: "PipAlreadyShown")
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
                                Task {
                                    await apiService.trackEvents(eventType: "clicked", campaignId: pipCampaign.id)
                                }
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
