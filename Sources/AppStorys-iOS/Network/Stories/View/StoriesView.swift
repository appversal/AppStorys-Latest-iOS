//
//  StoriesView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 03/04/25.
//

import SwiftUI
import AVKit
import Combine
import SDWebImageSwiftUI
import UIKit


struct StoryCircles: View {
    let storyGroups: [StoryDetails]
    let viewedStories: [String]
    let onStoryClick: (StoryDetails) -> Void
    
    var sortedStoryGroups: [StoryDetails] {
        storyGroups.sorted { first, second in
            if viewedStories.contains(first.id) && !viewedStories.contains(second.id) {
                return false
            } else if !viewedStories.contains(first.id) && viewedStories.contains(second.id) {
                return true
            } else {
                return first.order < second.order
            }
        }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sortedStoryGroups) { storyGroup in
                    if storyGroup.thumbnail.isEmpty == false {
                        StoryItem(
                            isStoryGroupViewed: viewedStories.contains(storyGroup.id),
                            imageUrl: storyGroup.thumbnail,
                            username: storyGroup.name ?? "",
                            ringColor: Color(hex: storyGroup.ringColor)!,
                            nameColor: Color(hex: storyGroup.nameColor)!,
                            onClick: { onStoryClick(storyGroup) }
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .padding(.vertical, 4)
        .safeAreaInset(edge: .leading) { Color.clear.frame(width: 0) }
        .safeAreaInset(edge: .trailing) { Color.clear.frame(width: 0) }
    }
}



struct StoryItem: View {
    let isStoryGroupViewed: Bool
    let imageUrl: String
    let username: String
    let ringColor: Color
    let nameColor: Color
    let onClick: () -> Void
    
    var body: some View {
        VStack(alignment: .center) {
            ZStack(alignment: .center) {
                Circle()
                    .strokeBorder(
                        isStoryGroupViewed ? Color.gray : ringColor,
                        lineWidth: 2.5
                    )
                    .frame(width: 74, height: 74)
                
                WebImage(url: URL(string: imageUrl))
                    .resizable()
                    .indicator(.activity)
                    .scaledToFill()
                    .frame(width: 65, height: 65)
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            
            Text(username)
                .font(.system(size: 12))
                .foregroundColor(nameColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 60, height: 32, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(4)
        .onTapGesture(perform: onClick)
    }
}

struct StoryScreen: View {
    let storyGroup: StoryDetails
    let onDismiss: () -> Void
    let slides: [StorySlide]
    let onStoryGroupEnd: () -> Void
    let sendEvent: (StorySlide, String) -> Void
    @State private var imageTimer: AnyCancellable?
    
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var currentSlideIndex = 0
    @State private var isHolding = false
    @State private var isMuted = false
    @State private var progress: CGFloat = 0
    @State private var completedSlides = Set<Int>()
    @State private var player: AVPlayer?
    @State private var shareData: ShareData?

    private var currentSlide: StorySlide {
        slides[currentSlideIndex]
    }
    
    private var isImage: Bool {
        currentSlide.image != nil
    }
    
    private let storyImageDuration: TimeInterval = 5.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                if #available(iOS 17.0, *) {
                    ZStack {
                        if let videoUrl = currentSlide.video, !videoUrl.isEmpty {
                            VideoPlayerView(player: player)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        } else if let imageUrl = currentSlide.image, !imageUrl.isEmpty {
                            WebImage(url: URL(string: imageUrl))
                                .resizable()
                                .indicator(.activity)
                                .scaledToFit()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        
                        if let link = currentSlide.link,
                           let buttonText = currentSlide.buttonText,
                           !link.isEmpty,
                           !buttonText.isEmpty {
                            VStack {
                                Spacer()
                                Button(action: {
                                    guard let url = URL(string: link) else { return }
                                    UIApplication.shared.open(url)
                                    sendEvent(currentSlide, "CLK")
                                }) {
                                    Text(buttonText)
                                        .foregroundColor(.black)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(8)
                                }
                                .padding(.bottom, 32)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isHolding {
                                    isHolding = true
                                    player?.pause()
                                    imageTimer?.cancel()
                                }
                            }
                            .onEnded { value in
                                let location = value.location
                                isHolding = false
                                player?.play()
                                
                                if isImage {
                                    startImageTimer()
                                }
                                
                                let screenWidth = geometry.size.width
                                if location.x < screenWidth / 2 {
                                    if currentSlideIndex > 0 {
                                        imageTimer?.cancel()
                                        player?.pause()
                                        completedSlides.remove(currentSlideIndex)
                                        currentSlideIndex -= 1
                                    }
                                } else {
                                    imageTimer?.cancel()
                                    player?.pause()
                                    handleSlideCompletion()
                                }
                            }
                    )
                }
                
                VStack {
                    HStack(spacing: 4) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            let progressValue: CGFloat = {
                                if index == currentSlideIndex {
                                    return progress
                                } else if index < currentSlideIndex || completedSlides.contains(index) {
                                    return 1.0
                                } else {
                                    return 0.0
                                }
                            }()
                            
                            ProgressBar(progress: progressValue)
                                .frame(height: 4)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                
                VStack {
                    HStack(alignment: .center) {
                        HStack {
                            WebImage(url: URL(string: storyGroup.thumbnail))
                                .resizable()
                                .indicator(.activity)
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                            
                            Text(storyGroup.name)
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                        }
                        
                        Spacer()
                        HStack(spacing: 4) {
                            Button(action: {
                                let slide = currentSlide
                                var itemsToShare: [Any] = []

                                if let image = slide.image, let url = URL(string: image) {
                                    itemsToShare = [url]
                                } else if let video = slide.video, let url = URL(string: video) {
                                    itemsToShare = [url]
                                }

                                if !itemsToShare.isEmpty {
                                    shareData = ShareData(items: itemsToShare)
                                }

                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.black.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            
                            if !isImage {
                                Button(action: {
                                    isMuted.toggle()
                                    player?.isMuted = isMuted
                                }) {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(Color.black.opacity(0.2))
                                        .clipShape(Circle())
                                }
                            }
                            
                            Button(action: onDismiss) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.black.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(18)
                    
                    Spacer()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .sheet(item: $shareData) { data in
            ActivityView(activityItems: data.items)
        }
        .onAppear {
            progress = 0
            sendEvent(currentSlide, "IMP")
            imageTimer?.cancel()
            setupMedia()
            configureSDWebImage()
            prefetchNextVideos()
        }
        .onChange(of: currentSlideIndex) { _ in
            progress = 0
            sendEvent(currentSlide, "IMP")
            imageTimer?.cancel()
            setupMedia()
            prefetchNextVideos()
        }
        .onDisappear {
            imageTimer?.cancel()
            player?.pause()
            player = nil
        }
    }
    
    private func configureSDWebImage() {
        SDImageCache.shared.config.maxMemoryCost = 100 * 1024 * 1024
        SDImageCache.shared.config.maxDiskSize = 200 * 1024 * 1024
        SDImageCache.shared.config.maxDiskAge = 7 * 24 * 60 * 60
        SDWebImageDownloader.shared.config.downloadTimeout = 15.0
    }
    
    private func prefetchNextVideos() {
        let nextIndices = [currentSlideIndex + 1, currentSlideIndex + 2]
        let videosToCache = nextIndices.compactMap { index -> URL? in
            guard index < slides.count, let videoUrl = slides[index].video, !videoUrl.isEmpty else {
                return nil
            }
            return URL(string: videoUrl)
        }
        
        if !videosToCache.isEmpty {
            VideoCacheManager.shared.prefetchVideos(urls: videosToCache)
        }
    }
    
    private func setupMedia() {
        if let existingPlayer = player {
            existingPlayer.pause()
            player = nil
        }
        if isImage {
            startImageTimer()
        } else if let videoUrl = currentSlide.video, let originalUrl = URL(string: videoUrl) {
            let videoURL = VideoCacheManager.shared.cachedURLForVideo(originalURL: originalUrl)
            
            let asset = AVAsset(url: videoURL)
            let playerItem = AVPlayerItem(asset: asset)
            let localPlayer = AVPlayer(playerItem: playerItem)
            
            localPlayer.isMuted = isMuted
            DispatchQueue.main.async {
                self.player = localPlayer
                localPlayer.play()
            }
            localPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
                let duration = playerItem.duration
                if duration.isIndefinite { return }
                
                let totalSeconds = CMTimeGetSeconds(duration)
                let currentTime = CMTimeGetSeconds(time)
                
                Task { @MainActor in
                    if !self.isHolding && totalSeconds > 0 {
                        self.progress = CGFloat(currentTime / totalSeconds)
                    }
                    
                    if currentTime >= totalSeconds - 0.1 {
                        self.handleSlideCompletion()
                    }
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    self.handleSlideCompletion()
                }
            }
            if !VideoCacheManager.shared.isVideoCached(url: originalUrl) {
                VideoCacheManager.shared.cacheVideo(url: originalUrl)
            }
        }
    }
    
    private func startImageTimer() {
        imageTimer?.cancel()
        imageTimer = Timer.publish(every: 0.016, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task { @MainActor in
                    if !self.isHolding {
                        self.progress += 0.016 / self.storyImageDuration
                        if self.progress >= 1.0 {
                            self.progress = 1.0
                            self.imageTimer?.cancel()
                            self.handleSlideCompletion()
                        }
                    }
                }
            }
    }
    
    @MainActor
    private func handleSlideCompletion() {
        guard !isHolding else { return }
        
        completedSlides.insert(currentSlideIndex)
        player?.pause()
        
        let nextIndex = currentSlideIndex + 1
        let isLastSlide = nextIndex >= slides.count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !isLastSlide {
                self.currentSlideIndex = nextIndex
            } else {
                self.onStoryGroupEnd()
                self.currentSlideIndex = 0
                self.completedSlides.removeAll()
            }
        }
    }
}

struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
struct ProgressBar: View {
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color.gray.opacity(0.5))
                Rectangle()
                    .frame(width: geometry.size.width * progress)
                    .foregroundColor(.white)
                    .animation(.linear, value: progress)
            }
        }
    }
}

struct StoriesApp: View {
    let storyGroups: [StoryDetails]
    let sendEvent: (StorySlide, String) -> Void
    let viewedStories: [String]
    let storyViewed: (String) -> Void
    
    @State private var selectedStoryGroup: StoryDetails?
    
    var body: some View {
        VStack {
            StoryCircles(
                storyGroups: storyGroups,
                viewedStories: viewedStories,
                onStoryClick: { storyGroup in
                    selectedStoryGroup = storyGroup
                    storyViewed(storyGroup.id)
                }
            )
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
        }
        .fullScreenCover(item: $selectedStoryGroup) { storyGroup in
            StoryScreen(
                storyGroup: storyGroup,
                onDismiss: { selectedStoryGroup = nil },
                slides: storyGroup.slides,
                onStoryGroupEnd: {
                    if let currentIndex = storyGroups.firstIndex(where: { $0.id == storyGroup.id }),
                       currentIndex < storyGroups.count - 1 {
                        selectedStoryGroup = storyGroups[currentIndex + 1]
                        storyViewed(storyGroups[currentIndex + 1].id)
                    } else {
                        selectedStoryGroup = nil
                    }
                },
                sendEvent: sendEvent
            )
        }
    }
}


struct StoryAppMain: View {
    let apiStoryGroups: [StoryDetails]
    let sendEvent: (StorySlide, String) -> Void
    
    @State private var viewedStories: [String] = []
    @State private var storyGroups: [StoryDetails] = []
    
    var body: some View {
        StoriesApp(
            storyGroups: storyGroups,
            sendEvent: sendEvent,
            viewedStories: viewedStories,
            storyViewed: { id in
                if !viewedStories.contains(id) {
                    viewedStories.append(id)
                    saveViewedStories(idList: viewedStories)
                }
            }
        )
        .edgesIgnoringSafeArea([])
        .onAppear {
            configureSDWebImage()
            loadViewedStories()
            sortStoryGroups()
            prefetchThumbnails()
            prefetchFirstSlideVideos()
        }
        .onChange(of: viewedStories) { _ in
            sortStoryGroups()
        }
    }
    
    private func configureSDWebImage() {
        SDImageCache.shared.config.maxMemoryCost = 100 * 1024 * 1024
        SDImageCache.shared.config.maxDiskSize = 200 * 1024 * 1024
        SDImageCache.shared.config.maxDiskAge = 7 * 24 * 60 * 60
        SDWebImageDownloader.shared.config.downloadTimeout = 15.0
    }
    
    private func prefetchThumbnails() {
        let urls = apiStoryGroups.compactMap { URL(string: $0.thumbnail) }
        SDWebImagePrefetcher.shared.prefetchURLs(urls)
        let firstSlideUrls = apiStoryGroups.compactMap { group -> URL? in
            guard let firstSlide = group.slides.first,
                  let imageUrl = firstSlide.image,
                  !imageUrl.isEmpty else {
                return nil
            }
            return URL(string: imageUrl)
        }
        SDWebImagePrefetcher.shared.prefetchURLs(firstSlideUrls)
    }
    
    private func prefetchFirstSlideVideos() {
        let firstSlideVideoUrls = apiStoryGroups.compactMap { group -> URL? in
            guard let firstSlide = group.slides.first,
                  let videoUrl = firstSlide.video,
                  !videoUrl.isEmpty else {
                return nil
            }
            return URL(string: videoUrl)
        }
        
        if !firstSlideVideoUrls.isEmpty {
            VideoCacheManager.shared.prefetchVideos(urls: firstSlideVideoUrls)
        }
    }
    
    private func sortStoryGroups() {
        storyGroups = apiStoryGroups.sorted { first, second in
            if viewedStories.contains(first.id) && !viewedStories.contains(second.id) {
                return false
            } else if !viewedStories.contains(first.id) && viewedStories.contains(second.id) {
                return true
            } else {
                return first.order < second.order
            }
        }
    }
    
    private func saveViewedStories(idList: [String]) {
        if let data = try? JSONEncoder().encode(idList),
           let string = String(data: data, encoding: .utf8) {
            KeychainHelper.shared.save(string, key: "VIEWED_STORIES")
        }
    }

    private func loadViewedStories() {
        guard let string = KeychainHelper.shared.get(key: "VIEWED_STORIES"),
              let data = string.data(using: .utf8),
              let loadedStories = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        viewedStories = loadedStories
    }
}

public struct StoriesView: View {
    @ObservedObject private var apiService = AppStorys()
    
    public init(apiService: AppStorys) {
        self.apiService = apiService
    }
    
    public var body: some View {
        if let storiesCampaign = apiService.storiesCampaigns.first,
           case let .stories(details) = storiesCampaign.details {
            StoryAppMain(
                apiStoryGroups: details,
                sendEvent: { slide, eventType in
                    Task {
                        do {
                            let type: ActionType = eventType == "IMP" ? .view : .click
                            try await apiService.trackAction(
                                type: type,
                                campaignID: storiesCampaign.id,
                                widgetID: nil,
                                storySlide: slide.id
                            )
                        } catch {
                        }
                    }
                }
            )
        }
    }
}
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
