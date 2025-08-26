//
//  Reels.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 01/04/25.
//

import SwiftUI
import AVKit
import Combine
import SDWebImageSwiftUI

struct ReelsRow: View {
    let reels: [Reel]
    let onReelClick: (Int) -> Void
    let height: CGFloat
    let width: CGFloat
    let cornerRadius: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            if #available(iOS 15.0, *) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Spacer()
                            .frame(width: 0)
                            .fixedSize()
                        
                        ForEach(Array(reels.enumerated()), id: \.element.id) { index, reel in
                            WebImage(url: URL(string: reel.thumbnail))
                                .resizable()
                                .indicator(.activity)
                                .transition(.fade(duration: 0.5))
                                .scaledToFill()
                                .frame(width: width, height: height)
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                .onTapGesture {
                                    onReelClick(index)
                                }
                                .contentShape(Rectangle())
                        }
                        Spacer()
                            .frame(width: 0)
                            .fixedSize()
                    }
                    .padding(.horizontal, 16)
                    .padding(.leading, geometry.safeAreaInsets.leading)
                    .padding(.trailing, geometry.safeAreaInsets.trailing)
                }
                .safeAreaInset(edge: .leading) { Color.clear.frame(width: 0) }
                .safeAreaInset(edge: .trailing) { Color.clear.frame(width: 0) }
            } else {
                // Fallback on earlier versions
            }
        }
        .frame(height: height + 32) 
    }
}


struct VideoPlayerViewReel: UIViewControllerRepresentable {
    let url: URL
    let isPlaying: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let videoURL = VideoCacheManager.shared.cachedURLForVideo(originalURL: url)
        let player = AVPlayer(url: videoURL)
        controller.player = player
        controller.showsPlaybackControls = false
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            Task { @MainActor in
                player.play()
            }
        }
        if !VideoCacheManager.shared.isVideoCached(url: url) {
            VideoCacheManager.shared.cacheVideo(url: url)
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if isPlaying {
            uiViewController.player?.play()
        } else {
            uiViewController.player?.pause()
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: ()) {
        uiViewController.player?.pause()
        uiViewController.player = nil
    }
}


struct VideoControlsOverlay: View {
    let reel: Reel
    let reelsDetails: ReelsDetails
    let isLiked: Bool
    let likesCount: Int
    let onLikeTapped: () -> Void
    let onShareTapped: () -> Void
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var shareData: ShareData?

    var body: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 8) {
                Button(action: onLikeTapped) {
                    VStack {
                        Image(systemName: "hand.thumbsup.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor(isLiked ? Color(hex: reelsDetails.styling.likeButtonColor) : .white)
                        
                        Text("\(likesCount)")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }

                if !reel.link.isEmpty {
                    Button(action: {
                        let slide = reel
                            if !slide.video.isEmpty, let url = URL(string: slide.video) {
                                shareData = ShareData(items: [url])
                            }
                        
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)

                            Text("Share")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .accessibilityLabel("Share Reel")
                    }
                }

            }
            .padding(.trailing, 16)
        }
        .sheet(item: $shareData) { data in
            ActivityView(activityItems: data.items)
        }

    }
    
    func presentShareSheet(with items: [Any]) {
        shareItems = items
        DispatchQueue.main.async {
            showShareSheet = true
        }
    }
}
struct ShareData: Identifiable {
    let id = UUID()
    let items: [Any]
}


struct ReelInfoOverlay: View {
    let reel: Reel
    let reelsDetails: ReelsDetails
    let onButtonTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !reel.descriptionText.isEmpty {
                Text(reel.descriptionText)
                    .foregroundColor(Color(hex: reelsDetails.styling.descriptionTextColor))
                    .font(.body)
                    .lineLimit(2)
                    .padding(.top, 20)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            if !reel.buttonText.isEmpty && !reel.link.isEmpty {
                Button(action: onButtonTap) {
                    Text(reel.buttonText)
                        .font(.headline)
                        .bold()
                        .foregroundColor(Color(hex: reelsDetails.styling.ctaTextColor))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: reelsDetails.styling.ctaBoxColor))
                        .cornerRadius(CGFloat(Int(reelsDetails.styling.cornerRadius) ?? 12))
                }
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.3))
    }
}

struct ReelContentView: View {
    let index: Int
    let currentPage: Int
    let reel: Reel
    let reelsDetails: ReelsDetails
    let isLiked: Bool
    let likesCount: Int
    let onLikeTapped: () -> Void
    let onShareTapped: () -> Void
    let onButtonTap: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let url = URL(string: reel.video), currentPage == index {
                VideoPlayerViewReel(url: url, isPlaying: currentPage == index)
                    .edgesIgnoringSafeArea(.all)
            }
            VStack {
                Spacer()
                VideoControlsOverlay(
                    reel: reel,
                    reelsDetails: reelsDetails,
                    isLiked: isLiked,
                    likesCount: likesCount,
                    onLikeTapped: onLikeTapped,
                    onShareTapped: onShareTapped
                )
                ReelInfoOverlay(
                    reel: reel,
                    reelsDetails: reelsDetails,
                    onButtonTap: onButtonTap
                )
            }
        }
    }
}

struct FullScreenVideoScreen: View {
    @Environment(\.presentationMode) var presentationMode
    let reelsDetails: ReelsDetails
    let reels: [Reel]
    @State private var likedReels: [String]
    @State private var currentPage: Int
    let startIndex: Int
    let onBack: () -> Void
    let sendLikesStatus: (Reel, String) -> Void
    let sendEvents: (Reel, String) -> Void
    
    @State private var likesState: [String: Int] = [:]
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating: Bool = false
    
    init(reelsDetails: ReelsDetails, reels: [Reel], likedReels: [String], startIndex: Int, onBack: @escaping () -> Void, sendLikesStatus: @escaping (Reel, String) -> Void, sendEvents: @escaping (Reel, String) -> Void) {
        self.reelsDetails = reelsDetails
        self.reels = reels
        self._likedReels = State(initialValue: likedReels)
        self.startIndex = startIndex
        self._currentPage = State(initialValue: startIndex)
        self.onBack = onBack
        self.sendLikesStatus = sendLikesStatus
        self.sendEvents = sendEvents
        var initialLikesState: [String: Int] = [:]
        for reel in reels {
            initialLikesState[reel.id] = reel.likes
        }
        self._likesState = State(initialValue: initialLikesState)
    }
    
    func sendReelLikeAction(reelId: String, action: String) async throws {
        guard let userID = KeychainHelper.shared.get(key: "userIDAppStorys"),
              let accessToken = KeychainHelper.shared.get(key: "accessTokenAppStorys") else {
            return
        }
        let apiBaseURL = "https://backend.appstorys.com"
        let endpoint = "\(apiBaseURL)/api/v1/campaigns/reel-like/"
        
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "Invalid URL", code: 400, userInfo: ["url": endpoint])
        }
        let payload: [String: Any] = [
            "reel": reelId,
            "action": action,
            "user_id": userID
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw NSError(domain: "JSON serialization error", code: 400, userInfo: nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
          return
        }
    }
    
    func handleLikeAction(for reel: Reel) {
        let isLiked = likedReels.contains(reel.id)
        let action = isLiked ? "unlike" : "like"
        if !isLiked {
            likedReels.append(reel.id)
            likesState[reel.id] = (likesState[reel.id] ?? 0) + 1
        } else {
            likedReels.removeAll { $0 == reel.id }
            likesState[reel.id] = (likesState[reel.id] ?? 1) - 1
        }
        KeychainHelper.shared.saveLikedReels(likedReels)
        Task {
            do {
                try await sendReelLikeAction(reelId: reel.id, action: action)
            } catch {
                return
            }
        }
        sendLikesStatus(reel, action)
    }

    
    func handleShareAction(for reel: Reel) {
        let activityVC = UIActivityViewController(
            activityItems: [reel.link],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    func handleCTAAction(for reel: Reel) {
        sendEvents(reel, "CLK")
        if let url = URL(string: reel.link) {
            UIApplication.shared.open(url)
        }
    }
    
    func changePage(to newPage: Int) {
        guard newPage >= 0 && newPage < reels.count && !isAnimating else { return }
        isAnimating = true
        withAnimation(.spring()) {
            currentPage = newPage
            dragOffset = 0
        }
        sendEvents(reels[newPage], "IMP")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                ZStack {
                    ForEach(Array(reels.enumerated()), id: \.element.id) { index, reel in
                        if abs(index - currentPage) <= 1 {
                            ReelContentView(
                                index: index,
                                currentPage: currentPage,
                                reel: reel,
                                reelsDetails: reelsDetails,
                                isLiked: likedReels.contains(reel.id),
                                likesCount: likesState[reel.id] ?? 0,
                                onLikeTapped: { handleLikeAction(for: reel) },
                                onShareTapped: { handleShareAction(for: reel) },
                                onButtonTap: { handleCTAAction(for: reel) }
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(y: CGFloat(index - currentPage) * geometry.size.height + dragOffset)
                            .zIndex(index == currentPage ? 1 : 0)
                        }
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isAnimating {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 100
                            if dragOffset < -threshold && currentPage < reels.count - 1 {
                                changePage(to: currentPage + 1)
                            } else if dragOffset > threshold && currentPage > 0 {
                                changePage(to: currentPage - 1)
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                
                VStack {
                    HStack {
                        Button(action: {
                            onBack()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                                .padding(12)
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)
                        Spacer()
                    }
                    .padding(.top, 8)
                    Spacer()
                }
                .padding(.top, 0)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .preferredColorScheme(.dark)
        .onChange(of: currentPage) { _ in
            prefetchAdjacentReels()
        }
        .onAppear {
            sendEvents(reels[currentPage], "IMP")
            prefetchAdjacentReels()
        }
    }
}

extension FullScreenVideoScreen {
    func prefetchAdjacentReels() {
        let urlsToCache = reels.enumerated().compactMap { index, reel -> URL? in
            if (index == currentPage + 1 || index == currentPage + 2 || index == currentPage - 1),
               let url = URL(string: reel.video) {
                return url
            }
            return nil
        }
        
        VideoCacheManager.shared.prefetchVideos(urls: urlsToCache)
    }
}

extension KeychainHelper {
    func saveLikedReels(_ idList: [String]) {
        if let data = try? JSONEncoder().encode(idList),
           let string = String(data: data, encoding: .utf8) {
            save(string, key: "LIKED_REELS")
        }
    }
    
    func getLikedReels() -> [String] {
        guard let string = get(key: "LIKED_REELS"),
              let data = string.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }
}

public struct ReelView: View {
    @ObservedObject private var apiService: AppStorys
    @State private var showFullScreen = false
    @State private var startIndex = 0
    @State private var currentReelsDetails: ReelsDetails? = nil
    @State private var selectedReelsDetails: ReelsDetails? = nil
    
    public init(apiService: AppStorys) {
        self.apiService = apiService
    }
    
    public var body: some View {
        VStack {
            if let details = currentReelsDetails {
                ReelsRow(
                    reels: details.reels,
                    onReelClick: { index in
                        startIndex = index
                        selectedReelsDetails = details
                        showFullScreen = true
                    },
                    height: CGFloat(Int(details.styling.thumbnailHeight) ?? 180),
                    width: CGFloat(Int(details.styling.thumbnailWidth) ?? 120),
                    cornerRadius: CGFloat(Int(details.styling.cornerRadius) ?? 12)
                )
                .padding(.vertical, 8)
                
                Spacer()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: apiService.reelsCampaigns) { newCampaigns in
            if let reelsCampaign = newCampaigns.first,
               case let .reel(details) = reelsCampaign.details {
                currentReelsDetails = details
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let details = currentReelsDetails,
               let campaignID = apiService.reelsCampaigns.first?.id {
                FullScreenVideoScreen(
                    reelsDetails: details,
                    reels: details.reels,
                    likedReels: KeychainHelper.shared.getLikedReels(),
                    startIndex: startIndex,
                    onBack: {
                        showFullScreen = false
                    },
                    sendLikesStatus: { reel, status in
                        var likedReels = KeychainHelper.shared.getLikedReels()
                        if status == "like" {
                            likedReels.append(reel.id)
                        } else {
                            likedReels.removeAll { $0 == reel.id }
                        }
                        KeychainHelper.shared.saveLikedReels(likedReels)
                    },
                    sendEvents: { reel, eventType in
                        Task {
                            do {
                                let type: ActionType = eventType == "viewed" ? .view : .click
                                apiService.trackEvents(
                                    eventType: type.rawValue,
                                    campaignId: campaignID,
                                    metadata: ["reel_id": reel.id]
                                )

                            } catch {
                                return
                            }
                        }
                    }
                )
            } else {
                ProgressView()
            }
        }
    }
}
