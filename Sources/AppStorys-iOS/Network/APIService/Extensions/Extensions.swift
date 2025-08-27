//
//  Extensions.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 30/07/25.
//

import SwiftUI

@available(iOS 13.0, *)
public extension View {
    func appstoryView(identifier: String?) -> some View {
        self.background(ASTagView(identifier: identifier))
    }
}

@available(iOS 13.0, *)
internal struct ASTagView: UIViewRepresentable {
    let identifier: String?

    func makeUIView(context: Context) -> UIView {
        return AppStoryTargetView(identifier: identifier)
    }
    func updateUIView(_ uiView: UIView, context: Context) {
    }
}

public extension UIColor {
    convenience init?(hex: String, alpha: CGFloat = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255

        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

public extension UIGestureRecognizer {
    convenience init(target: ClosureSleeve) {
        self.init(target: target, action: #selector(ClosureSleeve.invoke))
        objc_setAssociatedObject(self, UUID().uuidString, target, .OBJC_ASSOCIATION_RETAIN)
    }
}

public class ClosureSleeve {
    let closure: () -> Void
    init(_ closure: @escaping () -> Void) { self.closure = closure }
    @objc func invoke() { closure() }
}
