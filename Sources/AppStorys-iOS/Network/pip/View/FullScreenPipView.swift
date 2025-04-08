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
    
    public init(isVisible: Binding<Bool>, isPipVisible: Binding<Bool>,apiService: AppStorys) {
        self._isVisible = isVisible
        self._isPipVisible = isPipVisible
        self.apiService = apiService
    }
    
    public var body: some View {
        if isVisible {
            if let pipCampaign = apiService.pipCampaigns.first{
                if case let .pip(details) = pipCampaign.details,
                   let videoURL = details.smallVideo {
                    let videoWidth = CGFloat(details.width ?? 230)
                    let videoHeight = CGFloat(details.height ?? 405)
                    
                    ZStack {
                        CustomAVPlayerView(player: playerManager.player)
                            .frame(width:  UIScreen.main.bounds.width ,
                                   height: UIScreen.main.bounds.height )
                            .cornerRadius(15)
                            .shadow(radius: 5)
                            .offset(x:  0 , y:  0 )
                            .onAppear {
                                playerManager.updateVideoURL(videoURL)
                                playerManager.play()
                            }
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack (alignment:.leading){
                            HStack {
                                Button(action: {
                                    isMuted.toggle()
                                    playerManager.player.isMuted = isMuted
                                }) {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20 )
                                        .padding(5 )
                                }
                                .frame(width:35 , height: 35 )
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .padding(.leading, 20)
                                .padding(.top, 0 )
                                
                                Button(action: {   isVisible = false
                                    playerManager.player.pause()}) {
                                        Image(systemName: "rectangle.expand.vertical")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .padding(5)
                                            .clipShape(Circle())
                                    }
                                    .frame(width: 35, height: 35)
                                    .background(Color.gray)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                
                                    .padding(.top, 0 )
                                Spacer()
                                
                                Button(action: {
                                    isVisible = false
                                    isPipVisible = false
                                    playerManager.player.pause()
                                }) {
                                    Image(systemName: "xmark")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20 )
                                        .padding(5 )
                                }
                                
                                .frame(width:35 , height: 35 )
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .padding(.trailing, 20 )
                                .padding(.top,  0 )
                            }
                            .frame(alignment: .top)
                            
                        }
                        .padding(.bottom, UIScreen.main.bounds.height - 50)
                        .frame(width: UIScreen.main.bounds.width , height: UIScreen.main.bounds.height )
                        .offset(x:  0, y: 0)
                        
                        VStack {
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
                                .padding(.bottom, 50)
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width ,
                               height: UIScreen.main.bounds.height)
                        
                    }
                    .onAppear {
                    }
                    .frame(width: UIScreen.main.bounds.width ,
                           height: UIScreen.main.bounds.height)
                    .transition(.move(edge: .trailing))
                    
                } else {
                    ProgressView("Loading...")
                        .padding()
                        .onAppear {
                            
                        }
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
