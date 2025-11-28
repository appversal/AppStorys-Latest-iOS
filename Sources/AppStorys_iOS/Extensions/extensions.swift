import Foundation
public extension StringOrInt {
    var cgFloatValue: CGFloat {
        CGFloat(Double(self.stringValue) ?? 0)
    }
}
