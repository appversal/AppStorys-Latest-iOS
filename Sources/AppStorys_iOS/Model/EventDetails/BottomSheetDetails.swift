//
//  BottomSheetDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/10/25.
//


import Foundation

public struct BottomSheetDetails: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let cornerRadius: String?
    public let elements: [BottomSheetElement]?
    public let enableCrossButton: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, cornerRadius, elements
        case enableCrossButton = "enableCrossButton"
    }
}

public struct BottomSheetElement: Codable, Sendable {
    public let id: String
    public let type: String
    public let url: String?
    public let alignment: String?
    public let order: Int
    public let imageLink: String?
    public let overlayButton: Bool?
    public let paddingTop: Int?
    public let paddingBottom: Int?
    public let paddingLeft: Int?
    public let paddingRight: Int?
}