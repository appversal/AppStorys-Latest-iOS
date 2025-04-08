//
//  Reels.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 01/04/25.
//

import SwiftUI
import AVKit
import Combine

struct ReelsRow: View {
    let reels: [Reel]
    let onReelClick: (Int) -> Void
    let height: CGFloat
    let width: CGFloat
    let cornerRadius: CGFloat
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(reels.enumerated()), id: \.element.id) { index, reel in
                    AsyncImage(url: URL(string: reel.thumbnail)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .onTapGesture {
                        onReelClick(index)
                    }
                }
            }
            .padding(16)
        }
    }
}


struct VideoPlayerViewReel: UIViewControllerRepresentable {
    let url: URL
    let isPlaying: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
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
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 8) {
                // Like button
                Button(action: onLikeTapped) {
                    VStack {
                        Image(systemName: "heart.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor(isLiked ? Color(hex: reelsDetails.styling.likeButtonColor) : .white)
                        
                        Text("\(likesCount)")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                // Share button (if link exists)
                if !reel.link.isEmpty {
                    Button(action: onShareTapped) {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.white)
                            
                            Text("Share")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.trailing, 16)
        }
    }
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

// MARK: - Reel Content View
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
            
            // Content overlays
            VStack {
                Spacer()
                
                // Like and share buttons
                VideoControlsOverlay(
                    reel: reel,
                    reelsDetails: reelsDetails,
                    isLiked: isLiked,
                    likesCount: likesCount,
                    onLikeTapped: onLikeTapped,
                    onShareTapped: onShareTapped
                )
                
                // Description and CTA button
                ReelInfoOverlay(
                    reel: reel,
                    reelsDetails: reelsDetails,
                    onButtonTap: onButtonTap
                )
            }
        }
    }
}

// MARK: - Full Screen Video Screen
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
    // Add drag state to better control swipe gestures
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
        
        // Initialize likes state
        var initialLikesState: [String: Int] = [:]
        for reel in reels {
            initialLikesState[reel.id] = reel.likes
        }
        self._likesState = State(initialValue: initialLikesState)
    }
    
    // Helper functions
    func handleLikeAction(for reel: Reel) {
        let isLiked = likedReels.contains(reel.id)
        if !isLiked {
            likedReels.append(reel.id)
            likesState[reel.id] = (likesState[reel.id] ?? 0) + 1
        } else {
            likedReels.removeAll { $0 == reel.id }
            likesState[reel.id] = (likesState[reel.id] ?? 1) - 1
        }
        sendLikesStatus(reel, isLiked ? "unlike" : "like")
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
    
    // Function to safely change page with proper animation
    func changePage(to newPage: Int) {
        guard newPage >= 0 && newPage < reels.count && !isAnimating else { return }
        
        isAnimating = true
        withAnimation(.spring()) {
            currentPage = newPage
            dragOffset = 0
        }
        
        // Send impression event for new page
        sendEvents(reels[newPage], "IMP")
        
        // Reset animation flag after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Replace ScrollView with a more direct approach using ZStack and offset
                ZStack {
                    ForEach(Array(reels.enumerated()), id: \.element.id) { index, reel in
                        if abs(index - currentPage) <= 1 { // Only render adjacent reels for performance
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
                                // Swipe up to next reel
                                changePage(to: currentPage + 1)
                            } else if dragOffset > threshold && currentPage > 0 {
                                // Swipe down to previous reel
                                changePage(to: currentPage - 1)
                            } else {
                                // Reset if threshold not met
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                )

                // Back button overlay
                VStack {
                    HStack {
                        Button(action: {
                            onBack()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)
                        
                        Spacer()
                    }
                    .padding(.top, 16)
                    
                    Spacer()
                }
                .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0)
                
            }
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
        .onAppear {
            // Send impression event for initial reel
            sendEvents(reels[currentPage], "IMP")
        }
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
            Text("Reels")
                .font(.largeTitle)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            
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
                Spacer()
            } else {
                ProgressView("Loading Reels...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: apiService.reelsCampaigns) { newCampaigns in
            if let reelsCampaign = newCampaigns.first,
               case let .reel(details) = reelsCampaign.details {
                currentReelsDetails = details
            }
        }
        .onAppear {
            if let reelsCampaign = apiService.reelsCampaigns.first,
               case let .reel(details) = reelsCampaign.details {
                currentReelsDetails = details
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let details = currentReelsDetails {
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
                    }
                )
            }
        }
    }
}
