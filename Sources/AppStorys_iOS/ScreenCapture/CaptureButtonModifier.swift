////
////  CaptureButtonModifier.swift
////  AppStorys_iOS
////
////  Created by Ansh Kalra on 16/10/25.
////
//
//
////
////  View+CaptureOverlay.swift
////  AppStorys_iOS
////
////  Automatic capture button overlay
////
//
//import SwiftUI
//
//extension View {
//    /// Automatically adds a capture button if screen capture is enabled
//    ///
//    /// Usage:
//    /// ```swift
//    /// var body: some View {
//    ///     MyContent()
//    ///         .withCaptureButton()
//    /// }
//    /// ```
//    public func withCaptureButton(
//        position: ScreenCaptureButton.Position = .bottomCenter
//    ) -> some View {
//        modifier(CaptureButtonModifier(position: position))
//    }
//}
//
//private struct CaptureButtonModifier: ViewModifier {
//    @ObservedObject private var sdk = AppStorys.shared
//    let position: ScreenCaptureButton.Position
//    
//    func body(content: Content) -> some View {
//        ZStack(alignment: position.alignment) {
//            content
//            
//            if sdk.isScreenCaptureEnabled {
//                sdk.captureButton()
//                    .padding(position.padding)
//                    .transition(.scale.combined(with: .opacity))
//                    .animation(.spring(response: 0.3), value: sdk.isScreenCaptureEnabled)
//            }
//        }
//    }
//}
