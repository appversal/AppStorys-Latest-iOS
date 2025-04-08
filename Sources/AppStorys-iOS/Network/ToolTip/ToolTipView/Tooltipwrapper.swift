//
//  Tooltipwrapper.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 24/03/25.
//

import SwiftUI
import SDWebImageSwiftUI


public struct TabBarTooltipWrapper<Content: View>: View {
    @Binding var selectedTab: Int
    @State private var tooltipIndex = 0
    @State private var showTooltip = true
    @State private var tooltips: [AppStorys_iOS.Tooltip] = []
    
    @ObservedObject private var apiService: AppStorys
    let content: Content
    let targetNames: [String]
    var hasSeenTooltips: Bool {
        get {
            return KeychainHelper.shared.get(key: "hasSeenTooltips") == "true"
        }
        set {
            KeychainHelper.shared.save(newValue ? "true" : "false", key: "hasSeenTooltips")
        }
    }
    public init(apiService: AppStorys, selectedTab: Binding<Int>,targetNames: [String], @ViewBuilder content: () -> Content) {
        self.apiService = apiService
        self._selectedTab = selectedTab
        self.targetNames = targetNames
        self.content = content()
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { advanceTooltip() }
            
            content
                .disabled(showTooltip && !tooltips.isEmpty)
            
            if showTooltip && !tooltips.isEmpty {
                GeometryReader { geometry in
                    let screenWidth = geometry.size.width
                    let screenHeight = geometry.size.height
                    let tabBarHeight = getTabBarHeight()
                    let tabBarY = screenHeight - tabBarHeight / 2
                    
                    var tooltipWidth: CGFloat {
                        CGFloat(Double(tooltips[tooltipIndex].styling?.tooltipDimensions?.width ?? "140") ?? 140)
                    }
                    
                    let tabItemWidth = screenWidth / CGFloat(tooltips.count)
                    let highlightX = tabItemWidth * CGFloat(tooltipIndex) + tabItemWidth / 2
                    let safePadding: CGFloat = 10
                    
                    let adjustedHighlightX = min(
                        max(highlightX, tooltipWidth / 2 + safePadding),
                        screenWidth - tooltipWidth / 2 - safePadding
                    )
                    let highlightRadius: CGFloat = CGFloat(Double(tooltips[tooltipIndex].styling?.highlightRadius ?? "10") ?? 10)
                    let highlightPadding: CGFloat = CGFloat(Double(tooltips[tooltipIndex].styling?.highlightPadding ?? "6") ?? 6)
                    var tooltipHeight: CGFloat {
                        CGFloat(Double(tooltips[tooltipIndex].styling?.tooltipDimensions?.height ?? "140") ?? 140)
                    }
                    var arrowHeight: CGFloat {
                        CGFloat(Double(tooltips[tooltipIndex].styling?.tooltipArrow?.arrowHeight ?? "5") ?? 5)
                    }

                    
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                            .ignoresSafeArea()
                            .mask(
                                Rectangle()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: highlightRadius)
                                            .frame(
                                                width: (tabItemWidth * 0.8) + highlightPadding,
                                                height: 50 + highlightPadding
                                            )
                                            .position(x: highlightX, y: tabBarY - 15)
                                            .blendMode(.destinationOut)
                                    )
                            )
                            .compositingGroup()
                            .onTapGesture { advanceTooltip() }
                        
                        VStack {
                            Spacer()
                            TabBarTooltipView(tooltip: tooltips[tooltipIndex], alignment: getArrowAlignment(for: tooltipIndex, total: tooltips.count))
                                .position(x: adjustedHighlightX, y: tabBarY - (tooltipHeight / 2) - arrowHeight - 50)
                                .transition(.opacity)
                                .onTapGesture { advanceTooltip() }
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onChange(of: apiService.toolTipCampaigns) { newCampaigns in
            if !hasSeenTooltips, let campaign = newCampaigns.first, case let .toolTip(details) = campaign.details {
                let filteredTooltips = details.tooltips?.filter { targetNames.contains($0.target!) } ?? []
                if !filteredTooltips.isEmpty {
                    tooltips = filteredTooltips
                    tooltipIndex = 0
                    showTooltip = true
                }
            }
        }
    }
    
    private func getTabBarHeight() -> CGFloat {
        let defaultHeight: CGFloat = 49
        let safeAreaBottom = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
        return defaultHeight + safeAreaBottom
    }
    
    private func getArrowAlignment(for index: Int, total: Int) -> Alignment {
        if index == 0 {
            return .leading
        } else if index == total - 1 {
            return .trailing
        } else {
            return .center
        }
    }
    
    private func advanceTooltip() {
        if tooltipIndex < tooltips.count - 1 {
            withAnimation {
                tooltipIndex += 1
            }
        } else {
            withAnimation {
                showTooltip = false
                KeychainHelper.shared.save("true", key: "hasSeenTooltips")
            }
        }
    }
    
    private func logTooltipViewed(index: Int) {
        let tooltipId = tooltips[index].id
      
    }

    private func logTooltipClicked(index: Int) {
        let tooltipId = tooltips[index].id
    }

}


struct TabBarTooltipView: View {
    let tooltip: AppStorys_iOS.Tooltip
    let alignment: Alignment
    var elementFrame: CGRect?
    var screenWidth: CGFloat?
    
    var tooltipOffset: CGFloat {
        let maxWidth: CGFloat = 200
        let safeMargin: CGFloat = 16

        guard let elementFrame = elementFrame, let screenWidth = screenWidth else {
            return 0
        }

        let elementCenterX = elementFrame.midX
        if elementCenterX + maxWidth / 2 > screenWidth - safeMargin {
            let offset = screenWidth - safeMargin - maxWidth - elementCenterX
            return offset
        } else if elementCenterX - maxWidth / 2 < safeMargin {
            let offset = safeMargin - elementCenterX
            return offset
        } else {
            return 0
        }
    }

    var arrowOffset: CGFloat {
        let maxOffset = tooltipWidth / 2 - arrowWidth / 2 - 40
        let minOffset = -maxOffset

        if let elementFrame = elementFrame {
            let elementCenterX = elementFrame.midX
            let tooltipLeftEdge = elementCenterX - tooltipWidth / 2
            let tooltipRightEdge = elementCenterX + tooltipWidth / 2
            if tooltipLeftEdge < 16 {
                return minOffset
            } else if tooltipRightEdge > (screenWidth ?? UIScreen.main.bounds.width) - 16 {
                return maxOffset
            }
        }
        
        return max(min(-tooltipOffset, maxOffset), minOffset)
    }




    
    private var tooltipWidth: CGFloat {
        let width = CGFloat(Double(tooltip.styling?.tooltipDimensions?.width ?? "214.5") ?? 214.5)
        return width
    }
    
    private var tooltipHeight: CGFloat {
        let height = CGFloat(Double(tooltip.styling?.tooltipDimensions?.height ?? "140") ?? 140)
        return height
    }
    
    private var tooltipCornerRadius: CGFloat {
        CGFloat(Double(tooltip.styling?.tooltipDimensions?.cornerRadius ?? "18") ?? 18)
    }
    
    private var arrowWidth: CGFloat {
        CGFloat(Double(tooltip.styling?.tooltipArrow?.arrowWidth ?? "8") ?? 8)
    }
    
    private var arrowHeight: CGFloat {
        CGFloat(Double(tooltip.styling?.tooltipArrow?.arrowHeight ?? "5") ?? 5)
    }
    
    private var tooltipBackgroundColor: Color {
        if let bgColorHex = tooltip.styling?.backgroundColor {
            return Color(hex: bgColorHex)!
        }
        return Color.white
    }
    
    var body: some View {
        
        VStack(spacing: 0) {
            VStack {
                if let imageUrl = tooltip.url, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: tooltipWidth, height: tooltipHeight)
                                .cornerRadius(tooltipCornerRadius)
                                .clipped()
                        case .failure:
                            Text("Failed to load image").foregroundColor(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: tooltipWidth, height: tooltipHeight)
                    .background(Color.clear)
                } else {
                    Text("No Image Available")
                        .foregroundColor(.white)
                        .frame(width: tooltipWidth)
                }
            }.cornerRadius(tooltipCornerRadius)
            HStack {
                if alignment == .trailing { Spacer() }
                TabBarTriangle()
                    .fill(Color.white)
                    .frame(width: arrowWidth, height: arrowHeight)
                    .rotationEffect(.degrees(180))
                    .offset(x: arrowOffset)

                if alignment == .leading { Spacer() }
            }.padding(.leading, 50)
                .padding(.trailing, 50)
                .frame(width: tooltipWidth)
        }
        .background(Color.clear)
    }
    
    

}

struct TabBarTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}


public struct ElementTooltipWrapper<Content: View>: View {
    @Binding var showTooltip: Bool
    @State private var tooltipIndex = 0
    @State private var tooltips: [AppStorys_iOS.Tooltip] = []
    
    @ObservedObject private var apiService: AppStorys
    let content: Content
    let elementFrame: CGRect
    
    public init(apiService: AppStorys, showTooltip: Binding<Bool>, elementFrame: CGRect, @ViewBuilder content: () -> Content) {
        self.apiService = apiService
        self._showTooltip = showTooltip
        self.elementFrame = elementFrame
        self.content = content()
    }
    
    private var tooltipY: CGFloat {
        let padding: CGFloat = 10
        let tooltipHeight: CGFloat

        if let heightValue = tooltips[safe: tooltipIndex]?.styling?.tooltipDimensions?.height {
            if let height = heightValue as? CGFloat {
                tooltipHeight = height
            } else if let heightString = heightValue as? String, let height = Double(heightString) {
                tooltipHeight = CGFloat(height)
            } else {
                tooltipHeight = 50
            }
        } else {
            tooltipHeight = 50
        }

        var yPosition = elementFrame.minY - tooltipHeight - padding
        if yPosition < 0 {
            yPosition = padding
        }
        return yPosition
    }


    let screenWidth = UIScreen.main.bounds.width
    
    private var tooltipWidth: CGFloat {
        if let widthValue = tooltips[safe: tooltipIndex]?.styling?.tooltipDimensions?.width {
            if let width = widthValue as? CGFloat {
                return width
            } else if let widthString = widthValue as? String, let width = Double(widthString) {
                return CGFloat(width)
            }
        }
        return 214.5
    }
    
    private var tooltipX: CGFloat {
            let screenWidth = UIScreen.main.bounds.width
            var xPosition = elementFrame.midX
            xPosition = min(max(xPosition, tooltipWidth / 2), screenWidth - tooltipWidth / 2)

            return xPosition
        }
    
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { advanceTooltip() }
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .frame(width: elementFrame.width + 10, height: elementFrame.height + 10)
                                .position(x: elementFrame.midX, y: elementFrame.midY)
                                .blendMode(.destinationOut)
                        )
                )
            content
                .disabled(showTooltip && !tooltips.isEmpty)
            
            if showTooltip && !tooltips.isEmpty {
                GeometryReader { geometry in
                    ZStack {
                        VStack {
                            TabBarTooltipView(
                                tooltip: tooltips[tooltipIndex],
                                alignment: .center, elementFrame: elementFrame, screenWidth: screenWidth
                            )
                            .position(x: tooltipX, y: tooltipY + 50)
                            .transition(.opacity)
                            .onTapGesture { advanceTooltip() }
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onChange(of: elementFrame) { newFrame in
            if newFrame.width > 0 && newFrame.height > 0 {
                showTooltip = true
            }
        }
        .onChange(of: apiService.toolTipCampaigns) { newCampaigns in
            if let campaign = newCampaigns.first, case let .toolTip(details) = campaign.details {
                if let newTooltips = details.tooltips, !newTooltips.isEmpty {
                    tooltips = newTooltips
                }
            }
        }
    }
    
    private func advanceTooltip() {
        if tooltipIndex < tooltips.count - 1 {
            withAnimation { tooltipIndex += 1 }
        } else {
            withAnimation { showTooltip = false }
        }
    }
}

