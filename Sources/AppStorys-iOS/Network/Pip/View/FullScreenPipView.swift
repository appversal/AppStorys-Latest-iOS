//
//  FullScreenPipView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 02/03/25.
//


import SwiftUI
import AVKit

public struct FullScreenPipView : View {
    
    @State private var isMuted = false
    @State private var position = CGSize.zero
    @StateObject private var playerManager = AVPlayerManager()
    @Binding var isVisible: Bool
    @StateObject private var apiService = AppStorys()
    @Binding var isPipVisible: Bool

    
    let appID: String
    let accountID: String
    let screenName: String
    let positionID: String
    
    public init(appID: String, accountID: String, screenName: String, position: String, isVisible: Binding<Bool>, isPipVisible: Binding<Bool>) {
        self.appID = appID
        self.accountID = accountID
        self.screenName = screenName
        self.positionID = position
        self._isVisible = isVisible
        self._isPipVisible = isPipVisible
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
                        
                        if let linkString = campaign.details?.first?.link, let link = URL(string: linkString) {
                            Button(action: {
                                trackAction(campaignID: campaign.id, actionType: .click)
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
//                    apiService.validateAccount(appID: appID, accountID: accountID )
//                    apiService.trackScreen(screenName: "Home Screen", position: "1")
                }
                .frame(width: UIScreen.main.bounds.width ,
                       height: UIScreen.main.bounds.height)
                .transition(.move(edge: .trailing))
                // .animation(.easeInOut, value: isVisible)
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

#Preview {
    FullScreenPipView(
        appID: "afadf960-3975-4ba2-933b-fac71ccc2002",
        accountID: "13555479-077f-445e-87f0-e6eae2e215c5",
        screenName: "Home Screen",
        position: "1",
        isVisible: .constant(true), isPipVisible: .constant(true)
    )
}
