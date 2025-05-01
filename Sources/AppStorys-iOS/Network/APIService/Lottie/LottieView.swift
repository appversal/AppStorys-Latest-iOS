//
//  LottieView.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 18/04/25.
//

import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let animationURL: String

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        view.loopMode = .loop
        view.contentMode = .scaleAspectFit
        if let url = URL(string: animationURL) {
            LottieAnimation.loadedFrom(url: url) { animation in
                if let animation = animation {
                    view.animation = animation
                    view.play()
                }
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
    }
}
