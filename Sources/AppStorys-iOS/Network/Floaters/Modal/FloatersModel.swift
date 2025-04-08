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
}
