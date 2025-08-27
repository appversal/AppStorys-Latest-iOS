//
//  BottomSheetView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 12/04/25

import SwiftUI
import SDWebImageSwiftUI

extension View {
    func italicIfNeeded(_ decoration: String?) -> some View {
            if decoration?.lowercased().contains("italic") == true {
                if #available(iOS 16.0, *) {
                    return AnyView(self.italic())
                } else {
                    // Fallback on earlier versions
                }
            }
            return AnyView(self)
        }

        func underlineIfNeeded(_ decoration: String?) -> some View {
            if decoration?.lowercased().contains("underline") == true {
                if #available(iOS 16.0, *) {
                    return AnyView(self.underline())
                } else {
                    // Fallback on earlier versions
                }
            }
            return AnyView(self)
        }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

import SwiftUI

public struct BottomSheetView: View {
    @ObservedObject private var apiService: AppStorys
    @Binding var isShowing: Bool
    @State private var loadedImages: [String: Image] = [:]
    @State private var imageData: [String: UIImage] = [:]
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    @State private var offsetY: CGFloat = UIScreen.main.bounds.height
    
    public init(apiService: AppStorys, isShowing: Binding<Bool>) {
        self.apiService = apiService
        self._isShowing = isShowing
    }

    var bottomSheetDetails: BottomSheetDetails? {
        if let campaign = apiService.bottomSheetsCampaigns.first,
           case let .bottomSheets(details) = campaign.details {
            return details
        }
        return nil
    }

    @ViewBuilder
    public var body: some View {
        if let details = bottomSheetDetails {
            if let overlayValue = details.elements.first?.overlayButton, overlayValue == true {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation {
                                isShowing = false
                            }
                        }

                    bottomSheetContent(details: details)
                        .transition(.move(edge: .bottom))
                        .animation(.easeOut(duration: 0.3), value: isShowing)
                }
            } else {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation {
                                isShowing = false
                            }
                        }


                    VStack {
                        Spacer()
                        VStack(spacing: 0) {
                            ForEach(sortedElements(from: details.elements)) { element in
                                renderElement(element)
                            }
                        }
                        .cornerRadius(CGFloat(Int(details.cornerRadius ?? "16") ?? 16), corners: [.topLeft, .topRight])
                        .shadow(radius: 5)
                        .offset(y: dragOffset)
                        .gesture(
                            DragGesture()
                                .updating($isDragging) { value, state, _ in
                                    if value.translation.height > 0 {
                                        dragOffset = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height > 100 {
                                        withAnimation {
                                            isShowing = false
                                        }
                                    } else {
                                        withAnimation {
                                            dragOffset = 0
                                        }
                                    }
                                }
                        )
                    }
                    .edgesIgnoringSafeArea(.bottom)
                    .transition(.move(edge: .bottom))
                    .animation(.easeOut(duration: 0.3), value: isShowing)
                    .onAppear{
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isShowing = true
                            }
                        }
                    }
                }

            }
        } else {
            Text("No content available")
                .padding()
        }
    }


    private func sortedElements(from elements: [Element]) -> [Element] {
        return elements.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }
    
    @ViewBuilder
    private func bottomSheetContent(details: BottomSheetDetails) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                if details.enableCrossButton == "true" {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                }
                let sortedElements = details.elements.sorted(by: { $0.order < $1.order })
                let imageElements = sortedElements.filter { $0.type == .image }
                let bodyElements = sortedElements.filter { $0.type == .body }
                let ctaElements = sortedElements.filter { $0.type == .cta }
                createCombinedView(imageElements: imageElements, bodyElements: bodyElements, ctaElements: ctaElements)
            }
            .cornerRadius(CGFloat(Int(details.cornerRadius!) ?? 16), corners: [.topLeft, .topRight])
            .shadow(radius: 5)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .updating($isDragging) { value, state, _ in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            withAnimation {
                                isShowing = false
                            }
                        } else {
                            withAnimation {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .edgesIgnoringSafeArea(.bottom)
        .transition(.move(edge: .bottom))
        .onAppear {
            loadImages()
            if let campaign = apiService.bottomSheetsCampaigns.first {
                Task {
                    await apiService.trackEvents(eventType: "viewed", campaignId: campaign.id)
                }
            }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 3, dampingFraction: 0.8)) {
                                isShowing = true
                            }
                        }
        }
    }
    
    @ViewBuilder
    private func createCombinedView(imageElements: [Element], bodyElements: [Element], ctaElements: [Element]) -> some View {
        if let imageElement = imageElements.first {
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    if let urlString = imageElement.url, let url = URL(string: urlString) {
                        WebImage(url: url)
                            .resizable()
                            .indicator(.activity)
                            .transition(.fade(duration: 0.5))
                            .clipped()
                    } else {
                        Color.gray
                    }
                    
                    VStack {
                        Spacer()
                        VStack(spacing: 0) {
                            ForEach(bodyElements, id: \.id) { element in
                                bodyViewOverlay(element)
                            }
                            if !ctaElements.isEmpty {
                                horizontalCTAButtonsView(ctaElements)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 15)
                    }
                }
            }
            .frame(height: determineHeightForImageElement(imageElement))
        } else {
            VStack(spacing: 0) {
                ForEach(bodyElements, id: \.id) { element in
                    bodyView(element)
                }
                if !ctaElements.isEmpty {
                    horizontalCTAButtonsView(ctaElements)
                }
            }
        }
    }

    @ViewBuilder
    private func horizontalCTAButtonsView(_ elements: [Element]) -> some View {
        HStack(spacing: 0) {
            ForEach(elements, id: \.id) { element in
                HStack {
                    if element.ctaposition?.lowercased() == "left" {
                        Button(action: {
                            handleCTAAction(element)
                        }) {
                            ctaButtonContent(element)
                        }
                        Spacer()
                    } else if element.ctaposition?.lowercased() == "right" {
                        Spacer()
                        Button(action: {
                            handleCTAAction(element)
                        }) {
                            ctaButtonContent(element)
                        }
                    } else {
                        Spacer()
                        Button(action: {
                            handleCTAAction(element)
                        }) {
                            ctaButtonContent(element)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(.bottom, 20)
    }
    @ViewBuilder
    private func ctaButtonContent(_ element: Element) -> some View {
        Text(element.ctaText ?? "")
            .foregroundColor(Color(hex: element.ctaTextColour ?? "#FFFFFF"))
            .font(getFontSize(element.ctaFontSizeValue, fontFamily: element.ctaFontFamily ?? "Arial"))
            .underline(element.ctaFontDecoration?.lowercased() == "underline")
            .fontWeight(getFontWeight(element.ctaFontDecoration))
            // .italicIfNeeded(element.descriptionFontStyle?.decoration)
            // .underlineIfNeeded(element.descriptionFontStyle?.decoration)
            .frame(height: (element.ctaHeight != nil && element.ctaHeight! > 0) ? CGFloat(element.ctaHeight!) : 50)
            .frame(maxWidth: element.ctaFullWidth == true ? .infinity : nil)
            .padding(.horizontal, 20)
            .background(Color(hex: element.ctaBoxColor ?? "#0000FF"))
            .cornerRadius(CGFloat(element.ctaBorderRadius ?? 20))
    }

    
    @ViewBuilder
    private func advancedHorizontalCTAButtonsView(_ elements: [Element]) -> some View {
        let leftButtons = elements.filter { $0.ctaposition?.lowercased() == "left" }
        let centerButtons = elements.filter { $0.ctaposition?.lowercased() == "center" || $0.ctaposition == nil }
        let rightButtons = elements.filter { $0.ctaposition?.lowercased() == "right" }
        
        HStack(alignment: .center, spacing: 10) {
            if !leftButtons.isEmpty {
                HStack(spacing: 8) {
                    ForEach(leftButtons, id: \.id) { element in
                        Button(action: {
                            handleCTAAction(element)
                        }) {
                            ctaButtonContent(element)
                        }
                    }
                }
            }
            
            Spacer()
            if !centerButtons.isEmpty {
                HStack(spacing: 8) {
                    ForEach(centerButtons, id: \.id) { element in
                        Button(action: {
                            handleCTAAction(element)
                        }) {
                            ctaButtonContent(element)
                        }
                    }
                }
            }
            
            Spacer()
            if !rightButtons.isEmpty {
                HStack(spacing: 8) {
                    ForEach(rightButtons, id: \.id) { element in
                        Button(action: {
                            handleCTAAction(element)
                        }) {
                            ctaButtonContent(element)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 20)
    }
    
    private func determineHeightForImageElement(_ element: Element) -> CGFloat {
        if let uiImage = imageData[element.id] {
            let aspectRatio = uiImage.size.height / uiImage.size.width
            let baseWidth: CGFloat = UIScreen.main.bounds.width
            let calculatedHeight = baseWidth * aspectRatio
            return min(max(calculatedHeight, 50), 600)
        }
        return 600
    }
    
    private func loadImages() {
        guard let details = bottomSheetDetails else { return }
        
        for element in details.elements {
            if element.type == .image, let urlString = element.url, let url = URL(string: urlString) {
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data, let uiImage = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.imageData[element.id] = uiImage
                            self.loadedImages[element.id] = Image(uiImage: uiImage)
                        }
                    }
                }.resume()
            }
        }
    }

    @ViewBuilder
    private func renderElement(_ element: Element) -> some View {
        switch element.type {
        case .image:
            imageView(element)
            
        case .body:
            bodyView(element)
            
        case .cta:
            ctaView(element)
        }
    }
    
    @ViewBuilder
    private func imageView(_ element: Element) -> some View {
        if let urlString = element.url, let url = URL(string: urlString) {
            WebImage(url: url)
                .resizable()
                .indicator(.activity)
                .transition(.fade(duration: 0.5))
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()
                .padding(.leading, element.paddingLeftValue)
                .padding(.trailing, element.paddingRightValue)
                .padding(.top, element.paddingTopValue)
                .padding(.bottom, element.paddingBottomValue)
                .frame(alignment: viewAlignment(for: element.alignment))
        } else {
            Color.gray.frame(height: 200)
                .padding(.leading, element.paddingLeftValue)
                .padding(.trailing, element.paddingRightValue)
                .padding(.top, element.paddingTopValue)
                .padding(.bottom, element.paddingBottomValue)
        }
    }
    
    @ViewBuilder
    private func bodyView(_ element: Element) -> some View {
        VStack(alignment: horizontalAlignment(for: element.alignment)) {
            
            if let titleText = element.titleText, !titleText.isEmpty {
                if #available(iOS 16.0, *) {
                    Text(titleText)
//                        .font(getFontSize(element.titleFontSizeValue, fontFamily: element.titleFontStyle?.fontFamily ?? "Times New Roman"))
//                        .fontWeight(getFontWeight(element.titleFontStyle?.decoration))
//                        .italicIfNeeded(element.descriptionFontStyle?.decoration)
//                        .underlineIfNeeded(element.descriptionFontStyle?.decoration)
                        .foregroundColor(Color(hex: element.titleFontStyle?.colour ?? "#0000ff"))
//                        .underline(element.titleFontStyle?.decoration.lowercased() == "underline")
                        .multilineTextAlignment(textAlignment(for: element.alignment))
                        .lineSpacing(element.titleLineHeight ?? 1.5)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Fallback on earlier versions
                }
            }
            
            if let description = element.descriptionText {
                Text(description)
//                    .font(getFontSize(element.descriptionFontSizeValue, fontFamily: element.descriptionFontStyle?.fontFamily ?? "Arial"))
//                    .fontWeight(getFontWeight(element.descriptionFontStyle?.decoration))
//                    .italicIfNeeded(element.descriptionFontStyle?.decoration)
//                    .underlineIfNeeded(element.descriptionFontStyle?.decoration)
                    .foregroundColor(Color(hex: element.descriptionFontStyle?.colour ?? "#000000"))
                    .multilineTextAlignment(textAlignment(for: element.alignment))
                    .lineSpacing(element.descriptionLineHeight ?? 1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: viewAlignment(for: element.alignment))
        .padding(.leading, element.paddingLeftValue ?? 20)
        .padding(.trailing, element.paddingRightValue ?? 20)
        .padding(.top, element.paddingTopValue ?? 0)
        .padding(.bottom, element.paddingBottomValue ?? 20)
        .background(Color(hex: element.bodyBackgroundColor ?? "#ebad3c"))
    }
    
    @ViewBuilder
    private func bodyViewOverlay(_ element: Element) -> some View {
        VStack(alignment: horizontalAlignment(for: element.alignment)) {
            
            if let titleText = element.titleText, !titleText.isEmpty {
                if #available(iOS 16.0, *) {
                    Text(titleText)
//                        .font(getFontSize(element.titleFontSizeValue, fontFamily: element.titleFontStyle?.fontFamily ?? "Times New Roman"))
//                        .fontWeight(getFontWeight(element.titleFontStyle?.decoration))
//                        .italicIfNeeded(element.descriptionFontStyle?.decoration)
//                        .underlineIfNeeded(element.descriptionFontStyle?.decoration)
                        .foregroundColor(Color(hex: element.titleFontStyle?.colour ?? "#FFFFFF"))
//                        .underline(element.titleFontStyle?.decoration.lowercased() == "underline")
                        .multilineTextAlignment(textAlignment(for: element.alignment))
                        .lineSpacing(element.titleLineHeight ?? 1.5)
                    
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Fallback on earlier versions
                }
            }
            
            if let description = element.descriptionText {
                Text(description)
//                    .font(getFontSize(element.descriptionFontSizeValue, fontFamily: element.descriptionFontStyle?.fontFamily ?? "Arial"))
//                    .fontWeight(getFontWeight(element.descriptionFontStyle?.decoration))
//                    .italicIfNeeded(element.descriptionFontStyle?.decoration)
//                    .underlineIfNeeded(element.descriptionFontStyle?.decoration)
                    .foregroundColor(Color(hex: element.descriptionFontStyle?.colour ?? "#FFFFFF"))
                    .multilineTextAlignment(textAlignment(for: element.alignment))
                    .lineSpacing(element.descriptionLineHeight ?? 1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: viewAlignment(for: element.alignment))
        .padding(.leading, element.paddingLeftValue ?? 20)
        .padding(.trailing, element.paddingRightValue ?? 20)
        .padding(.top, element.paddingTopValue ?? 0)
        .padding(.bottom, element.paddingBottomValue ?? 10)

    }

    @ViewBuilder
    private func ctaView(_ element: Element) -> some View {
        let position = getCTAPosition(element.ctaposition ?? "center")
        
        HStack {
            switch position {
            case .left:
                Button(action: {
                    handleCTAAction(element)
                }) {
                    ctaButtonContent(element)
                }
                Spacer()
            case .right:
                Spacer()
                Button(action: {
                    handleCTAAction(element)
                }) {
                    ctaButtonContent(element)
                }
            case .center:
                Spacer()
                Button(action: {
                    handleCTAAction(element)
                }) {
                    ctaButtonContent(element)
                }
                Spacer()
            }
        }
        .background(Color(hex: element.ctaBackgroundColor ?? "#0000FF"))
        .cornerRadius(CGFloat(element.ctaBorderRadius ?? 20))
        .padding(.leading, element.paddingLeftValue)
        .padding(.trailing, element.paddingRightValue)
        .padding(.top, element.paddingTopValue)
        .padding(.bottom, element.paddingBottomValue)
    }
    @ViewBuilder
    private func ctaViewOverlay(_ element: Element) -> some View {
        let position = getCTAPosition(element.ctaposition ?? "center")
        HStack {
            switch position {
            case .left:
                Button(action: {
                    handleCTAAction(element)
                }) {
                    ctaButtonContent(element)
                }
                Spacer()
            case .right:
                Spacer()
                Button(action: {
                    handleCTAAction(element)
                }) {
                    ctaButtonContent(element)
                }
            case .center:
                Spacer()
                Button(action: {
                    handleCTAAction(element)
                }) {
                    ctaButtonContent(element)
                }
                Spacer()
            }
        }
        .padding(.leading, element.paddingLeftValue)
        .padding(.trailing, element.paddingRightValue)
        .padding(.top, element.paddingTopValue)
        .padding(.bottom, element.paddingBottomValue ?? 20)
    }
    
    private func getCTAPosition(_ positionString: String) -> Element.Alignment {
        let position = positionString.lowercased()
        switch position {
        case "left":
            return .left
        case "right":
            return .right
        default:
            return .center
        }
    }

    
    private func handleCTAAction(_ element: Element) {
        if let campaign = apiService.bottomSheetsCampaigns.first {
                Task {
                    await apiService.trackEvents(eventType: "clicked", campaignId: campaign.id)
                }
                apiService.clickEvent(link: element.ctaLink, campaignId: campaign.id, widgetImageId: "")
        }
    }
    
    private func getFontWeight(_ decoration: String?) -> Font.Weight {
        guard let decoration = decoration?.lowercased() else { return .regular }
    
        switch decoration {
        case "bold": return .bold
        default: return .regular
        }
    }
    
    private func horizontalAlignment(for alignment: Element.Alignment) -> HorizontalAlignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private func viewAlignment(for alignment: Element.Alignment) -> Alignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
    
    private func textAlignment(for alignment: Element.Alignment) -> TextAlignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
    private func getFontSize(_ size: CGFloat?, fontFamily: String? = nil) -> Font {
        let fontSize = size ?? 16

        if let family = fontFamily {
            return Font.customFont(family: family, size: fontSize)
        } else {
            return Font.timesNewRoman(size: fontSize)
        }
    }

}

extension Font {
    static func timesNewRoman(size: CGFloat) -> Font {
        return Font.custom("Times New Roman", size: size)
    }
    
    static func customFont(family: String?, size: CGFloat) -> Font {
        if let family = family?.lowercased() {
            switch family {
            case "times new roman", "times", "tnr":
                return .custom("Times New Roman", size: size)
            case "arial":
                return .custom("Arial", size: size)
            case "helvetica":
                return .custom("Helvetica", size: size)
            case "roboto":
                return .custom("Roboto", size: size)
            case "open sans", "opensans":
                return .custom("Open Sans", size: size)
            default:
                return .system(size: size)
            }
        }
        return .system(size: size)
    }
}
