//
//  BottomSheetView.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//

import SwiftUI
import UIKit

public struct BottomSheetView: View {
    // MARK: - Properties
    
    public let campaignId: String
    public let details: BottomSheetDetails
    
    @State private var isPresented = false
    @State private var hasTrackedView = false
    @State private var isPresentedLinkError = false
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Computed Properties
    
    private var cornerRadius: CGFloat {
        guard let radiusString = details.cornerRadius,
              let radius = Double(radiusString) else {
            return 20
        }
        return CGFloat(radius)
    }
    
    private var showCloseButton: Bool {
        details.enableCrossButton?.lowercased() == "true"
    }
    
    private var sortedElements: [BottomSheetElement] {
        (details.elements ?? []).sorted { $0.order < $1.order }
    }
    
    // MARK: - Initializer
    
    public init(campaignId: String, details: BottomSheetDetails) {
        self.campaignId = campaignId
        self.details = details
    }
    
    // MARK: - Body
    
    public var body: some View {
        // Bottom sheet content
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                
                // Dynamic content elements
                    VStack(spacing: 0) {
                        // 🖼️ Image elements (no background)
                        ForEach(sortedElements, id: \.id) { element in
                            if element.type == "image" {
                                elementView(for: element)
                            }
                        }

                        // ✅ Body + CTA group with background
                        VStack(spacing: 0) {
                            ForEach(sortedElements.filter { ["body", "cta"].contains($0.type) }, id: \.id) { element in
                                elementView(for: element)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(backgroundColor(
                                    sortedElements.first(where: { $0.type == "body" })?.bodyBackgroundColor
                                ))
                        )
                    }
            }
            .background(
                Rectangle()
                    .fill(.clear)
                    .onTapGesture {
                        handleDismiss()
                    })
            
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                Group{
                    if showCloseButton {
                        closeButton
                    }
                }
                    .offset(y: -32)
                ,alignment: .topLeading
            )

            .offset(y: isPresented ? 0 : UIScreen.main.bounds.height)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            animateIn()
            trackViewIfNeeded()
        }
        .alert(isPresented: $isPresentedLinkError) {
            Alert(
                title: Text("Unable to open link"),
                message: Text("The link is invalid or cannot be opened."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        HStack {
            Spacer()
            
            Button(action: handleDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color(.systemGray5))
                    )
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }
    
    // MARK: - Element Views
    
    @ViewBuilder
    private func elementView(for element: BottomSheetElement) -> some View {
        switch element.type {
        case "image":
            imageElement(element)
        case "body":
            bodyElement(element)
        case "cta":
            ctaElement(element)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Image Element
    
    @ViewBuilder
    private func imageElement(_ element: BottomSheetElement) -> some View {
        Button(action: {
            handleImageTap(element)
        }) {
            AppStorysImageView(
                url: URL(string: element.url ?? ""),
                contentMode: .fill,
                showShimmer: true,
                cornerRadius: 0,
                onSuccess: {
                    Logger.debug("✅ Bottom sheet image loaded")
                },
                onFailure: { error in
                    Logger.warning("⚠️ Bottom sheet image failed: \(error.localizedDescription)")
                }
            )
            .aspectRatio(contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(element.imageLink == nil || element.imageLink?.isEmpty == true)
        .padding(.top, paddingValueOrZero(element.paddingTop))
        .padding(.bottom, paddingValueOrZero(element.paddingBottom))
        .padding(.leading, paddingValue(element.paddingLeft))
        .padding(.trailing, paddingValue(element.paddingRight))
    }
    
    // MARK: - Body Element
    
    @ViewBuilder
    private func bodyElement(_ element: BottomSheetElement) -> some View {
        VStack(alignment: horizontalAlignment(element.alignment), spacing: spacingValue(element.spacingBetweenTitleDesc)) {
            // Title
            if let titleText = element.titleText, !titleText.isEmpty {
                Text(titleText)
                    .font(.system(size: CGFloat(element.titleFontSize ?? 16)))
                    .foregroundColor(fontColor(element.titleFontStyle))
                    .fontWeight(isBold(element.titleFontStyle) ? .bold : .regular)
                    .italic(isItalic(element.titleFontStyle))
                    .underline(isUnderlined(element.titleFontStyle))
                    .lineSpacing(lineSpacing(element.titleLineHeight))
                    .multilineTextAlignment(textAlignment(element.alignment))
                    .frame(maxWidth: .infinity, alignment: alignment(element.alignment))
            }
            
            // Description
            if let descText = element.descriptionText, !descText.isEmpty {
                Text(descText)
                    .font(.system(size: CGFloat(element.descriptionFontSize ?? 14)))
                    .foregroundColor(fontColor(element.descriptionFontStyle))
                    .fontWeight(isBold(element.descriptionFontStyle) ? .bold : .regular)
                    .italic(isItalic(element.descriptionFontStyle))
                    .underline(isUnderlined(element.descriptionFontStyle))
                    .lineSpacing(lineSpacing(element.descriptionLineHeight))
                    .multilineTextAlignment(textAlignment(element.alignment))
                    .frame(maxWidth: .infinity, alignment: alignment(element.alignment))
            }
        }
        .padding(.top, paddingValueOrZero(element.paddingTop))
        .padding(.bottom, paddingValueOrZero(element.paddingBottom))
        .padding(.leading, paddingValue(element.paddingLeft))
        .padding(.trailing, paddingValue(element.paddingRight))
        .background(backgroundColor(element.bodyBackgroundColor))
    }
    
    // MARK: - CTA Element
    
    @ViewBuilder
        private func ctaElement(_ element: BottomSheetElement) -> some View {
            let ctaFullWidth = element.ctaFullWidth == true
            let ctaWidth = CGFloat(element.ctaWidth ?? 120)
            let ctaHeight = CGFloat(element.ctaHeight ?? 50)
            
            Button(action: {
                handleCTATap(element)
            }) {
                Text(element.ctaText ?? "Click Me")
                    .font(.system(size: CGFloat(element.ctaFontSize ?? 16)))
                    .fontWeight(isBoldCTA(element.ctaFontDecoration) ? .bold : .medium)
                    .italic(isItalicCTA(element.ctaFontDecoration))
                    .underline(isUnderlinedCTA(element.ctaFontDecoration))
                    .foregroundColor(fontColor(element.ctaTextColour))
                    .frame(
                        maxWidth: ctaFullWidth ? .infinity : ctaWidth,
                        minHeight: ctaHeight,
                        maxHeight: ctaHeight
                    )
                    .background(
                        RoundedRectangle(cornerRadius: CGFloat(element.ctaBorderRadius ?? 8), style: .continuous)
                            .fill(backgroundColor(element.ctaBoxColor))
                    )
            }
            .padding(.top, paddingValueOrZero(element.paddingTop))
            .padding(.bottom, paddingValueOrZero(element.paddingBottom))
            .padding(.leading, paddingValue(element.paddingLeft))
            .padding(.trailing, paddingValue(element.paddingRight))
            .frame(maxWidth: .infinity, alignment: ctaAlignment(element.position))
        }
    
    // MARK: - Actions
    
    private func handleImageTap(_ element: BottomSheetElement) {
        guard let link = element.imageLink,
              !link.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        Task {
            await trackEvent(name: "clicked", metadata: ["element": "image", "element_id": element.id])
        }
        
        guard let url = URL(string: link) else {
            Logger.warning("⚠️ Invalid image link")
            return
        }
        
        openURL(url)
    }
    
    private func handleCTATap(_ element: BottomSheetElement) {
        Task {
            await trackEvent(name: "clicked", metadata: ["element": "cta", "element_id": element.id])
        }
        
        guard let link = element.ctaLink,
              !link.trimmingCharacters(in: .whitespaces).isEmpty,
              let url = URL(string: link) else {
            Logger.warning("⚠️ No valid CTA link")
            return
        }
        
        openURL(url)
    }
    
    private func handleDismiss() {
        Task {
            await trackEvent(name: "dismissed")
        }
        
        animateOut()
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func openURL(_ url: URL) {
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if !success {
                        isPresentedLinkError = true
                        Logger.warning("⚠️ Failed to open URL: \(url.absoluteString)")
                    }
                }
            } else {
                isPresentedLinkError = true
                Logger.warning("⚠️ Cannot open URL: \(url.absoluteString)")
            }
        }
    }
    
    // MARK: - Animations
    
    private func animateIn() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = true
        }
    }
    
    private func animateOut() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isPresented = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            AppStorys.shared.dismissCampaign(campaignId)
        }
    }
    
    // MARK: - Tracking
    
    private func trackViewIfNeeded() {
        guard !hasTrackedView else { return }
        hasTrackedView = true
        
        Task {
            await trackEvent(name: "viewed")
        }
    }
    
    private func trackEvent(name: String, metadata: [String: Any]? = nil) async {
        await AppStorys.shared.trackEvents(
            eventType: name,
            campaignId: campaignId,
            metadata: metadata
        )
    }
    
    // MARK: - Style Helpers
    
    // MARK: - Padding Helpers

    private func paddingValue(_ value: PaddingValue?) -> CGFloat {
        guard let value = value else { return 0 }
        return CGFloat(value.intValue)
    }

    // ✅ Overloaded convenience for SwiftUI modifiers that expect CGFloat directly
    private func paddingValueOrZero(_ value: PaddingValue?) -> CGFloat {
        CGFloat(value?.intValue ?? 0)
    }

    private func spacingValue(_ value: String?) -> CGFloat {
        guard let value = value, let spacing = Double(value) else { return 8 }
        return CGFloat(spacing)
    }
    
    private func lineSpacing(_ lineHeight: Double?) -> CGFloat {
        guard let lineHeight = lineHeight else { return 0 }
        return CGFloat((lineHeight - 1.0) * 16) // Approximate conversion
    }
    
    private func fontColor(_ style: FontStyle?) -> Color {
        guard let hex = style?.colour else { return .primary }
        return Color(hex: hex)
    }
    
    private func fontColor(_ hex: String?) -> Color {
        guard let hex = hex else { return .primary }
        return Color(hex: hex)
    }
    
    private func backgroundColor(_ hex: String?) -> Color {
        guard let hex = hex else { return .clear }
        return Color(hex: hex)
    }
    
    private func isBold(_ style: FontStyle?) -> Bool {
        style?.decoration?.contains("bold") ?? false
    }
    
    private func isItalic(_ style: FontStyle?) -> Bool {
        style?.decoration?.contains("italic") ?? false
    }
    
    private func isUnderlined(_ style: FontStyle?) -> Bool {
        style?.decoration?.contains("underline") ?? false
    }
    
    private func isBoldCTA(_ decorations: [String]?) -> Bool {
        decorations?.contains("bold") ?? false
    }
    
    private func isItalicCTA(_ decorations: [String]?) -> Bool {
        decorations?.contains("italic") ?? false
    }
    
    private func isUnderlinedCTA(_ decorations: [String]?) -> Bool {
        decorations?.contains("underline") ?? false
    }
    
    private func alignment(_ alignmentString: String?) -> Alignment {
        switch alignmentString?.lowercased() {
        case "left": return .leading
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }
    
    private func horizontalAlignment(_ alignmentString: String?) -> HorizontalAlignment {
        switch alignmentString?.lowercased() {
        case "left": return .leading
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }
    
    private func textAlignment(_ alignmentString: String?) -> TextAlignment {
        switch alignmentString?.lowercased() {
        case "left": return .leading
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }
    
    private func ctaAlignment(_ position: String?) -> Alignment {
        switch position?.lowercased() {
        case "left": return .leading
        case "center": return .center
        case "right": return .trailing
        default: return .center
        }
    }
}
