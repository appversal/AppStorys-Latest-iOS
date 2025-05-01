//
//  FloaterView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.
//
import SwiftUI
import Combine
import SDWebImageSwiftUI

public struct OverlayFloater: View {
    
    @ObservedObject private var apiService: AppStorys
    @State private var isFloaterVisible: Bool = true
    
    public init(apiService: AppStorys) {
        self.apiService = apiService
    }
    public var body: some View {
        VStack {
            if let floaterCampaign = apiService.floaterCampaigns.first,
               case let .floater(details) = floaterCampaign.details,
               let imageUrl = details.image {
                let floaterId = floaterCampaign.id
                let link = details.link
                let height = details.height ?? 60
                let width = details.width ?? 60
                let position = details.position ?? "right"
                Spacer()
                HStack {
                    if position != "left" {
                        Spacer()
                    }
                    Button(action: {
                        Task {
                            await apiService.trackAction(type: .click, campaignID: floaterId, widgetID: "")
                        }
                        apiService.clickEvent(link: link, campaignId: floaterId, widgetImageId: "")
                        
                    }) {
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

                    }
                    
                    if position == "left" {
                        Spacer()
                    }
                }
                .onAppear {
                    Task {
                        await apiService.trackAction(type: .view, campaignID: floaterId, widgetID: "")
                    }
                }
            }
        }
        .padding()
    }
}

extension NSNumber {
    var cgFloatValue: CGFloat { CGFloat(truncating: self) }
}
