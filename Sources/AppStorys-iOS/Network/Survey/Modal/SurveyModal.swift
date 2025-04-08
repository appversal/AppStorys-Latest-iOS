//
//  SurveyModal.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.
//

import Foundation

public struct SurveyDetails : Codable {
    let id: String
    let name: String?
    let styling: [String: String]
    let surveyQuestion: String
    let surveyOptions: [String: String]
    let hasOthers: Bool
    let campaign: String
}

struct SurveyOption {
    let id: String
    let name: String
}
