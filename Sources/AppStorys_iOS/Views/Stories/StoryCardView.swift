//
//  StoryCardView.swift
//  AppStorys_iOS
//
//  Fixed: Removed viewer-level gestures (moved to pager for proper separation)
//

import SwiftUI
import Combine

struct StoryCardView: View {
    @ObservedObject var manager: StoryManager
    let campaign: StoryCampaign
    let story: StoryDetails
    let groupIndex: Int
    let dragOffsetOpacity: CGFloat  // ✅ NEW: Passed from pager for UI fading
    let onDismiss: () -> Void
    
    // ✅ Card-level state only
    @State private var timerCancellable: AnyCancellable?
    @State private var timerProgress: CGFloat = 0
    @State private var isMediaReady = false
    @State private var hasMarkedComplete = false
    @State private var isMuted = false
    
    @State private var timerHealthCheckCounter: Int = 0
    
    private let defaultSlideDuration: TimeInterval = 5.0
    private let timerInterval: TimeInterval = 0.1
    
    private var isActive: Bool {
        manager.currentGroupIndex == groupIndex
    }
    
    private var currentSlide: StorySlide {
        let index = min(Int(timerProgress), story.slides.count - 1)
        return story.slides[index]
    }
    
    private var isCurrentSlideVideo: Bool {
        currentSlide.mediaType == .video
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                StoryMediaView(
                    slide: currentSlide,
                    isActive: isActive,
                    isPaused: manager.isPaused,
                    isMuted: isMuted,
                    onReady: { isMediaReady = true },
                    onVideoEnd: {
                        guard !hasMarkedComplete else { return }
                        let currentSlideIndex = min(Int(timerProgress), story.slides.count - 1)
                        if currentSlideIndex < story.slides.count - 1 {
                            timerProgress = CGFloat(currentSlideIndex + 1)
                        } else {
                            markCompletedAndAdvance()
                        }
                    }
                )
                .ignoresSafeArea()
                
                // ✅ CARD-LEVEL GESTURE: Tap zones for slide navigation
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleBackward()
                        }
                        .frame(width: proxy.size.width * 0.3)
                    
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleForward()
                        }
                }
                // ✅ Only allow taps when not dragging
                .allowsHitTesting(dragOffsetOpacity > 0.9)
            }
            
            // ✅ UI Overlay with drag-based opacity
            .overlay(
                VStack(spacing: 4) {
                    StoryProgressBar(
                        slideCount: story.slides.count,
                        currentProgress: timerProgress
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    StoryHeader(
                        story: story,
                        showMuteButton: isCurrentSlideVideo,
                        isMuted: isMuted,
                        onMuteToggle: {
                            isMuted.toggle()
                        },
                        onClose: onDismiss,
                        opacity: dragOffsetOpacity  // ✅ Fade during drag
                    )
                    
                    Spacer()
                }
            )
            
            // ✅ CARD-LEVEL VISUAL: Rotation effect during swipe
            .rotation3DEffect(
                getAngle(proxy: proxy),
                axis: (x: 0, y: 1, z: 0),
                anchor: proxy.frame(in: .global).minX > 0 ? .leading : .trailing,
                perspective: 2.5
            )
        }
        .onAppear {
            // ✅ Only reset if this is truly first appearance
            // Don't reset if we're becoming visible again after being in TabView
            if timerProgress == 0 && !isMediaReady {
                resetStoryState(preserveMediaReady: false)
            }
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: manager.currentGroupIndex) { oldValue, newValue in
            if newValue == groupIndex {
                // ✅ Becoming active
                let wasInactive = oldValue != groupIndex
                
                // ✅ If switching back to this group, preserve media ready state
                // (cached content won't re-trigger onReady callback)
                let shouldPreserveMedia = wasInactive && isMediaReady
                
                resetStoryState(preserveMediaReady: shouldPreserveMedia)
                startTimer()
                manager.onGroupIndexChanged()
                
                Logger.debug("🔄 Story group \(groupIndex) activated (from: \(oldValue), preserved media: \(shouldPreserveMedia))")
            } else {
                // ✅ Becoming inactive - stop timer
                stopTimer()
                Logger.debug("⏸️ Story group \(groupIndex) deactivated - timer stopped")
            }
        }
    }
    
    // MARK: - Timer Lifecycle
    
    /// ✅ Start a fresh timer - clean slate
    private func startTimer() {
        stopTimer()
        
        Logger.debug("▶️ Starting timer for story group \(groupIndex)")
        
        timerCancellable = Timer.publish(every: timerInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak manager] _ in
                guard let manager = manager else { return }
                guard manager.currentGroupIndex == groupIndex else { return }
                
                // ✅ Health check - detect stuck timers
                if !manager.isPaused && isMediaReady {
                    timerHealthCheckCounter += 1
                    
                    if timerHealthCheckCounter > 100 && timerProgress < 0.1 {
                        Logger.error("🚨 Timer stuck! Progress: \(timerProgress), Check: \(timerHealthCheckCounter)")
                        // Force recovery
                        isMediaReady = true
                    }
                }
                
                guard !manager.isPaused && isMediaReady else { return }
                guard !hasMarkedComplete else { return }
                
                let currentSlideIndex = min(Int(timerProgress), story.slides.count - 1)
                
                if currentSlideIndex == story.slides.count - 1 && !manager.isGroupViewed(story.id) {
                    manager.markGroupFullyViewed(storyId: story.id, campaignId: campaign.id)
                }
                
                timerProgress += timerInterval / defaultSlideDuration
                
                if timerProgress >= CGFloat(story.slides.count) {
                    markCompletedAndAdvance()
                } else if timerProgress >= CGFloat(currentSlideIndex + 1) {
                    let slide = story.slides[currentSlideIndex]
                    manager.markSlideViewed(
                        storyId: story.id,
                        slideId: slide.id,
                        campaignId: campaign.id
                    )
                }
            }
    }
    
    /// ✅ Stop and clean up timer
    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        Logger.debug("⏹️ Timer stopped for story group \(groupIndex)")
    }
    
    private func resetStoryState(preserveMediaReady: Bool = false) {
        timerProgress = 0
        hasMarkedComplete = false
        
        // ✅ Only reset isMediaReady if content isn't cached
        if !preserveMediaReady {
            isMediaReady = false
        }
        
        Logger.debug("🔄 Story state reset for group \(groupIndex) (preserving media: \(preserveMediaReady), ready: \(isMediaReady))")
    }
    
    // MARK: - Helper Methods
    
    private func handleBackward() {
        hasMarkedComplete = false
        
        if timerProgress < 1.0 {
            moveToGroup(forward: false)
        } else {
            timerProgress = CGFloat(Int(timerProgress) - 1)
        }
    }
    
    private func handleForward() {
        let currentSlideIndex = min(Int(timerProgress), story.slides.count - 1)
        
        if currentSlideIndex >= story.slides.count - 1 {
            guard !hasMarkedComplete else { return }
            markCompletedAndAdvance()
        } else {
            timerProgress = CGFloat(currentSlideIndex + 1)
        }
    }
    
    private func markCompletedAndAdvance() {
        hasMarkedComplete = true
        manager.markGroupFullyViewed(storyId: story.id, campaignId: campaign.id)
        timerProgress = CGFloat(story.slides.count)
        moveToGroup(forward: true)
    }
    
    private func moveToGroup(forward: Bool) {
        if !forward {
            if groupIndex > 0 {
                withAnimation {
                    manager.currentGroupIndex = groupIndex - 1
                }
            } else {
                timerProgress = 0
            }
        } else {
            if groupIndex < campaign.stories.count - 1 {
                withAnimation {
                    manager.currentGroupIndex = groupIndex + 1
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onDismiss()
                }
            }
        }
    }
    
    private func getAngle(proxy: GeometryProxy) -> Angle {
        let progress = proxy.frame(in: .global).minX / proxy.size.width
        let rotationAngle: CGFloat = 45
        return Angle(degrees: Double(rotationAngle * progress))
    }
}
