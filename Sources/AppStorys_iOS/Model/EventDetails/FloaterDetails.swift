//
//  FloaterDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/10/25.
//


import Foundation

public struct FloaterDetails: Codable, Sendable {
    public let id: String?
    public let image: String?
    public let link: String?
    public let height: Double?
    public let width: Double?
    public let position: String?
    public let styling: FloaterStyling?
}

public struct FloaterStyling: Codable, Sendable {
    public let topLeftRadius: String?
    public let topRightRadius: String?
    public let bottomLeftRadius: String?
    public let bottomRightRadius: String?
}