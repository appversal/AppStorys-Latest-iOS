//
//  ArrowDirection.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//


import SwiftUI

// MARK: - Arrow Direction

enum ArrowDirection {
    case up, down, left, right
}

// MARK: - Tooltip Shape

/// Tooltip shape with Apple's squircle continuous corners (superellipse)
struct TooltipShape: Shape {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let arrowDirection: ArrowDirection
    let arrowWidth: CGFloat
    let arrowHeight: CGFloat
    let arrowOffset: CGFloat
    let useContinuousCorners: Bool = true
    let arrowCornerRadius: CGFloat = 3 // Radius for arrow tip curve (intruding)
    let arrowBaseRadius: CGFloat = 2    // Radius for arrow base curves (extruding)
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = width
        let h = height
        let r = min(cornerRadius, min(width, height) / 2)
        let aw = arrowWidth
        let ah = arrowHeight
        
        let offsetX = (rect.width - w) / 2
        let offsetY = (rect.height - h) / 2
        
        // Clamp arrow offset
        let maxOffset = (arrowDirection == .up || arrowDirection == .down)
            ? (w / 2 - aw / 2 - r)
            : (h / 2 - aw / 2 - r)
        let clampedOffset = max(-maxOffset, min(maxOffset, arrowOffset))
        
        switch arrowDirection {
        case .up:
            drawArrowUp(path: &path, offsetX: offsetX, offsetY: offsetY, w: w, h: h, r: r, aw: aw, ah: ah, offset: clampedOffset)
        case .down:
            drawArrowDown(path: &path, offsetX: offsetX, offsetY: offsetY, w: w, h: h, r: r, aw: aw, ah: ah, offset: clampedOffset)
        case .left:
            drawArrowLeft(path: &path, offsetX: offsetX, offsetY: offsetY, w: w, h: h, r: r, aw: aw, ah: ah, offset: clampedOffset)
        case .right:
            drawArrowRight(path: &path, offsetX: offsetX, offsetY: offsetY, w: w, h: h, r: r, aw: aw, ah: ah, offset: clampedOffset)
        }
        
        return path
    }
    
    // MARK: - Arrow Curve Helpers
    
    /// Adds a smooth curve at arrow tip (intruding - curves inward)
    private func addArrowTipCurve(path: inout Path, from: CGPoint, tip: CGPoint, to: CGPoint) {
        let radius = arrowCornerRadius
        
        // Calculate vectors from tip to base points
        let v1 = CGPoint(x: from.x - tip.x, y: from.y - tip.y)
        let v2 = CGPoint(x: to.x - tip.x, y: to.y - tip.y)
        
        // Normalize and scale by radius
        let len1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let len2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        
        let p1 = CGPoint(x: tip.x + v1.x / len1 * radius, y: tip.y + v1.y / len1 * radius)
        let p2 = CGPoint(x: tip.x + v2.x / len2 * radius, y: tip.y + v2.y / len2 * radius)
        
        // Add curved corner with control point at tip (intruding curve)
        path.addLine(to: p1)
        path.addQuadCurve(to: p2, control: tip)
    }
    
    /// Adds a smooth curve at arrow base (extruding - curves outward)
    private func addArrowBaseCurve(path: inout Path, from: CGPoint, corner: CGPoint, to: CGPoint) {
        let radius = arrowBaseRadius
        
        // Calculate vectors
        let v1 = CGPoint(x: corner.x - from.x, y: corner.y - from.y)
        let v2 = CGPoint(x: to.x - corner.x, y: to.y - corner.y)
        
        let len1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let len2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        
        // Points before and after corner
        let p1 = CGPoint(x: corner.x - v1.x / len1 * radius, y: corner.y - v1.y / len1 * radius)
        let p2 = CGPoint(x: corner.x + v2.x / len2 * radius, y: corner.y + v2.y / len2 * radius)
        
        // Calculate outward control point for extruding curve
        let perpX = -v1.y / len1
        let perpY = v1.x / len1
        let controlPoint = CGPoint(
            x: corner.x + perpX * radius * 0.5,
            y: corner.y + perpY * radius * 0.5
        )
        
        path.addLine(to: p1)
        path.addQuadCurve(to: p2, control: controlPoint)
    }
    
    // MARK: - Squircle Corner Implementation
    
    /// Adds Apple's squircle corner (superellipse: x⁴ + y⁴ = r⁴)
    /// This creates the distinctive "pillowy yet crisp" iOS continuous corner
    private func addSquircleCorner(
        path: inout Path,
        center: CGPoint,
        radius: CGFloat,
        startAngle: Angle,
        endAngle: Angle
    ) {
        if useContinuousCorners {
            // Apple's squircle uses a superellipse approximation with specific control points
            // The key is using asymmetric control point distances that match the squircle curve
            
            let start = angleToPoint(center: center, radius: radius, angle: startAngle)
            let end = angleToPoint(center: center, radius: radius, angle: endAngle)
            
            // Squircle-optimized control point distance (not circular 0.552!)
            // This value (≈0.64) creates the "squarish-smooth" curve characteristic of iOS
            let squircleConstant: CGFloat = 0.64
            let cp1Distance = radius * squircleConstant
            let cp2Distance = radius * squircleConstant
            
            // Calculate control points tangent to the curve at start/end
            let cp1 = CGPoint(
                x: start.x + cp1Distance * cos(startAngle.radians + .pi / 2),
                y: start.y + cp1Distance * sin(startAngle.radians + .pi / 2)
            )
            let cp2 = CGPoint(
                x: end.x + cp2Distance * cos(endAngle.radians - .pi / 2),
                y: end.y + cp2Distance * sin(endAngle.radians - .pi / 2)
            )
            
            path.addCurve(to: end, control1: cp1, control2: cp2)
        } else {
            // Standard circular arc
            path.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
        }
    }
    
    private func angleToPoint(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle.radians),
            y: center.y + radius * sin(angle.radians)
        )
    }
    
    // MARK: - Arrow Drawing Methods
    
    private func drawArrowUp(path: inout Path, offsetX: CGFloat, offsetY: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat, aw: CGFloat, ah: CGFloat, offset: CGFloat) {
        let arrowTip = CGPoint(x: offsetX + w / 2 + offset, y: offsetY - ah)
        let arrowLeft = CGPoint(x: offsetX + w / 2 + offset - aw / 2, y: offsetY)
        let arrowRight = CGPoint(x: offsetX + w / 2 + offset + aw / 2, y: offsetY)
        
        path.move(to: arrowLeft)
        addArrowTipCurve(path: &path, from: arrowLeft, tip: arrowTip, to: arrowRight)
        addArrowBaseCurve(path: &path, from: arrowTip, corner: arrowRight, to: CGPoint(x: offsetX + w - r, y: offsetY))
        path.addLine(to: CGPoint(x: offsetX + w - r, y: offsetY))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + w - r, y: offsetY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0))
        path.addLine(to: CGPoint(x: offsetX + w, y: offsetY + h - r))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + w - r, y: offsetY + h - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90))
        path.addLine(to: CGPoint(x: offsetX + r, y: offsetY + h))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + r, y: offsetY + h - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180))
        path.addLine(to: CGPoint(x: offsetX, y: offsetY + r))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + r, y: offsetY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270))
        addArrowBaseCurve(path: &path, from: CGPoint(x: offsetX + r, y: offsetY), corner: arrowLeft, to: arrowTip)
        path.closeSubpath()
    }
    
    private func drawArrowDown(path: inout Path, offsetX: CGFloat, offsetY: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat, aw: CGFloat, ah: CGFloat, offset: CGFloat) {
        let arrowTip = CGPoint(x: offsetX + w / 2 + offset, y: offsetY + h + ah)
        let arrowLeft = CGPoint(x: offsetX + w / 2 + offset - aw / 2, y: offsetY + h)
        let arrowRight = CGPoint(x: offsetX + w / 2 + offset + aw / 2, y: offsetY + h)
        
        path.move(to: CGPoint(x: offsetX + r, y: offsetY))
        path.addLine(to: CGPoint(x: offsetX + w - r, y: offsetY))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + w - r, y: offsetY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0))
        path.addLine(to: CGPoint(x: offsetX + w, y: offsetY + h - r))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + w - r, y: offsetY + h - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90))
        addArrowBaseCurve(path: &path, from: CGPoint(x: offsetX + w - r, y: offsetY + h), corner: arrowRight, to: arrowTip)
        addArrowTipCurve(path: &path, from: arrowRight, tip: arrowTip, to: arrowLeft)
        addArrowBaseCurve(path: &path, from: arrowTip, corner: arrowLeft, to: CGPoint(x: offsetX + r, y: offsetY + h))
        path.addLine(to: CGPoint(x: offsetX + r, y: offsetY + h))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + r, y: offsetY + h - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180))
        path.addLine(to: CGPoint(x: offsetX, y: offsetY + r))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + r, y: offsetY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270))
        path.closeSubpath()
    }
    
    private func drawArrowLeft(path: inout Path, offsetX: CGFloat, offsetY: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat, aw: CGFloat, ah: CGFloat, offset: CGFloat) {
        let arrowTip = CGPoint(x: offsetX - ah, y: offsetY + h / 2 + offset)
        let arrowTop = CGPoint(x: offsetX, y: offsetY + h / 2 + offset - aw / 2)
        let arrowBottom = CGPoint(x: offsetX, y: offsetY + h / 2 + offset + aw / 2)
        
        path.move(to: CGPoint(x: offsetX + r, y: offsetY))
        path.addLine(to: CGPoint(x: offsetX + w - r, y: offsetY))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + w - r, y: offsetY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0))
        path.addLine(to: CGPoint(x: offsetX + w, y: offsetY + h - r))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + w - r, y: offsetY + h - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90))
        path.addLine(to: CGPoint(x: offsetX + r, y: offsetY + h))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + r, y: offsetY + h - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180))
        addArrowBaseCurve(path: &path, from: CGPoint(x: offsetX, y: offsetY + h - r), corner: arrowBottom, to: arrowTip)
        addArrowTipCurve(path: &path, from: arrowBottom, tip: arrowTip, to: arrowTop)
        addArrowBaseCurve(path: &path, from: arrowTip, corner: arrowTop, to: CGPoint(x: offsetX, y: offsetY + r))
        path.addLine(to: CGPoint(x: offsetX, y: offsetY + r))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + r, y: offsetY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270))
        path.closeSubpath()
    }
    
    private func drawArrowRight(path: inout Path, offsetX: CGFloat, offsetY: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat, aw: CGFloat, ah: CGFloat, offset: CGFloat) {
        let arrowTip = CGPoint(x: offsetX + w + ah, y: offsetY + h / 2 + offset)
        let arrowTop = CGPoint(x: offsetX + w, y: offsetY + h / 2 + offset - aw / 2)
        let arrowBottom = CGPoint(x: offsetX + w, y: offsetY + h / 2 + offset + aw / 2)
        
        path.move(to: CGPoint(x: offsetX + r, y: offsetY))
        path.addLine(to: CGPoint(x: offsetX + w - r, y: offsetY))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + w - r, y: offsetY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0))
        addArrowBaseCurve(path: &path, from: CGPoint(x: offsetX + w, y: offsetY + r), corner: arrowTop, to: arrowTip)
        addArrowTipCurve(path: &path, from: arrowTop, tip: arrowTip, to: arrowBottom)
        addArrowBaseCurve(path: &path, from: arrowTip, corner: arrowBottom, to: CGPoint(x: offsetX + w, y: offsetY + h - r))
        path.addLine(to: CGPoint(x: offsetX + w, y: offsetY + h - r))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + w - r, y: offsetY + h - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90))
        path.addLine(to: CGPoint(x: offsetX + r, y: offsetY + h))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + r, y: offsetY + h - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180))
        path.addLine(to: CGPoint(x: offsetX, y: offsetY + r))
        addSquircleCorner(path: &path, center: CGPoint(x: offsetX + r, y: offsetY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270))
        path.closeSubpath()
    }
}
