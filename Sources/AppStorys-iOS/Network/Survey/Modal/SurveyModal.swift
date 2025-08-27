//
//  SurveyModal.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 31/03/25.
//

import Foundation

public struct SurveyDetails : Codable, Sendable {
    let id: String
    let name: String?
    let styling: [String: String]
    let surveyQuestion: String
    let surveyOptions: [String: String]
    let hasOthers: Bool
}

struct SurveyOption  {
    let id: String
    let name: String
}
