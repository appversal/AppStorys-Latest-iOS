//
//  FloatersModel.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.
//

import SwiftUI
import Combine
import SDWebImageSwiftUI

struct FloaterDetails: Codable {
    let id: String
    let image: String?
    let link: LinkType
    let height: CGFloat?
    let width: CGFloat?
    let position: String?
    let styling: FloaterStyling?
}

struct FloaterStyling: Codable {
    let topLeftRadius: String?
    let topRightRadius: String?
    let bottomLeftRadius: String?
    let bottomRightRadius: String?
    
    var topLeftCGFloat: CGFloat {
        CGFloat(Double(topLeftRadius ?? "") ?? 0)
    }
    var topRightCGFloat: CGFloat {
        CGFloat(Double(topRightRadius ?? "") ?? 0)
    }
    var bottomLeftCGFloat: CGFloat {
        CGFloat(Double(bottomLeftRadius ?? "") ?? 0)
    }
    var bottomRightCGFloat: CGFloat {
        CGFloat(Double(bottomRightRadius ?? "") ?? 0)
    }
}
