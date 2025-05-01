//
//  ModalView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 22/04/25.
//



import SwiftUI
import SDWebImageSwiftUI
import Lottie

public struct PopupModal: View {
    var onCloseClick: () -> Void
    @Environment(\.openURL) var openURL
    @State private var showModal = true
    @ObservedObject private var apiService: AppStorys
    
    public init(onCloseClick: @escaping () -> Void, apiService: AppStorys) {
        self.onCloseClick = onCloseClick
        self.apiService = apiService
    }
    
    public var body: some View {
        Group {
            if showModal, let modalsCampaign = apiService.modalsCampaigns.first {
                if case let .modals(details) = modalsCampaign.details, !details.modals.isEmpty {
                    ModalContentView(
                        details: details,
                        onCloseClick: onCloseClick,
                        onDismiss: { showModal = false },
                        openURL: openURL,
                        campaignID: modalsCampaign.id,
                        apiService: apiService
                    )
                    .task {
                        do {
                            print("action tracked for view")
                            try await apiService.trackAction(
                                type: .view,
                                campaignID: modalsCampaign.id,
                                widgetID: ""
                            )
                        } catch {
                            print("Failed to track view action: \(error.localizedDescription)")
                        }
                    }
                } else {
                    // Handle case where modals details are invalid
                    EmptyView()
                }
            } else {
                EmptyView()
            }
        }
    }
}

private struct BackgroundOverlay: View {
    let opacity: Double
    let onTap: () -> Void
    
    var body: some View {
        Color.black.opacity(max(0, min(opacity, 1)))
            .edgesIgnoringSafeArea(.all)
            .onTapGesture(perform: onTap)
    }
}

private struct ModalItemView: View {
    let modal: Modal
    let onDismiss: () -> Void
    let openURL: OpenURLAction
    let campaignID: String
    let apiService: AppStorys
    private var borderRadius: CGFloat {
        CGFloat(Double(modal.borderRadius) ?? 16)
    }
    
    private var size: CGFloat {
        CGFloat(Double(modal.size) ?? 200)
    }
    
    private func handleTap() {
        Task {
            do {
                try await apiService.trackAction(
                    type: .click,
                    campaignID: campaignID,
                    widgetID: ""
                )
            } catch {
                print("Failed to track click action: \(error.localizedDescription)")
            }
        }
        
        apiService.clickEvent(link: modal.link, campaignId: campaignID, widgetImageId: "")
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if modal.mediaType.uppercased() == "LOTTIE" {
                LottieAnimationView(
                    url: modal.url,
                    width: size,
                    radius: borderRadius,
                    onTap: handleTap
                )
                .padding(8)
            } else {
                Group {
                    if let url = URL(string: modal.url) {
                        WebImage(url: url)
                            .resizable()
                            .indicator(.activity)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size)
                            .clipShape(RoundedRectangle(cornerRadius: borderRadius))
                            .onTapGesture(perform: handleTap)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: borderRadius))
                            .overlay(
                                Text("Invalid Image URL")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .padding(8)
            }
            
            CloseButton(onTap: onDismiss)
        }
    }
}

private struct LottieAnimationView: View {
    let url: String
    let width: CGFloat
    let radius: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        if URL(string: url) != nil {
            LottieView(animationURL: url)
                .frame(width: width)
                .clipShape(RoundedRectangle(cornerRadius: radius))
                .onTapGesture(perform: onTap)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: width, height: width)
                .clipShape(RoundedRectangle(cornerRadius: radius))
                .overlay(
                    Text("Invalid Animation URL")
                        .foregroundColor(.gray)
                )
                .onTapGesture(perform: onTap)
        }
    }
}

private struct CloseButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: "xmark")
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .padding(6)
                .background(Color.black)
                .clipShape(Circle())
        }
    }
}

private struct ModalContentView: View {
    let details: ModalsDetails
    let onCloseClick: () -> Void
    let onDismiss: () -> Void
    let openURL: OpenURLAction
    let campaignID: String
    let apiService: AppStorys
    
    var body: some View {
        ZStack {
            // Get background opacity with safe fallback
            let opacity = details.modals.first?.backgroundOpacity ?? 0.5
            
            BackgroundOverlay(
                opacity: opacity,
                onTap: {
                    onDismiss()
                    onCloseClick()
                }
            )
            
            // Only render modals if they exist
            if !details.modals.isEmpty {
                ForEach(details.modals) { modal in
                    ModalItemView(
                        modal: modal,
                        onDismiss: {
                            onDismiss()
                            onCloseClick()
                        },
                        openURL: openURL,
                        campaignID: campaignID,
                        apiService: apiService
                    )
                }
            }
        }
    }
}
