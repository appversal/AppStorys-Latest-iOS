//
//  FloaterView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.
//
import SwiftUI
import Combine
import SDWebImageSwiftUI

@MainActor func showOverlayFloater(with apiService: AppStorys) -> some View {
    return OverlayFloater(apiService: apiService)
}
public struct OverlayFloater: View {
    
    @ObservedObject private var apiService: AppStorys
    @State private var isFloaterVisible: Bool = true
    
    public init(apiService: AppStorys) {
        self.apiService = apiService
    }
    
    public var body: some View {
        if let floaterCampaign = apiService.floaterCampaigns.first,
           case let .floater(details) = floaterCampaign.details,
           let imageUrl = details.image {
            let floaterId = floaterCampaign.id
            let link = details.link
            let height = CGFloat(details.height ?? 60)
            let width = CGFloat(details.width ?? 60)
            
            WebImage(url: URL(string: imageUrl))
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .mask(
                    RoundedCorners(
                        topLeft: details.styling?.topLeftCGFloat ?? 0,
                        topRight: details.styling?.topRightCGFloat ?? 0,
                        bottomLeft: details.styling?.bottomLeftCGFloat ?? 0,
                        bottomRight: details.styling?.bottomRightCGFloat ?? 0
                    )
                )
                .background(Color.red.opacity(0.3)) // Debug background
                .onTapGesture {
                    print("Floater tapped!") // Debug print
                    Task {
                        await apiService.trackEvents(eventType: "clicked", campaignId: floaterId)
                    }
                    apiService.clickEvent(link: link, campaignId: floaterId, widgetImageId: "")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle()) // Ensure entire area is tappable
                .onAppear {
                    print("Floater appeared") // Debug print
                    Task {
                        await apiService.trackEvents(eventType: "viewed", campaignId: floaterId)
                    }
                }
        } else {
            // Empty view if no campaign
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// Helper extensions
extension FloaterDetails {
    var heightCGFloat: CGFloat {
        return CGFloat(height ?? 60)
    }
    
    var widthCGFloat: CGFloat {
        return CGFloat(width ?? 60)
    }
}

extension NSNumber {
    var cgFloatValue: CGFloat { CGFloat(truncating: self) }
}
