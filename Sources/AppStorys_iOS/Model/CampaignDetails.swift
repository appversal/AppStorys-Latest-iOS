////
////  CampaignDetails.swift
////  AppStorys_iOS
////
////  Created by Ansh Kalra on 08/10/25.
////
//
//import Foundation
//
//// MARK: - Campaign Details (Polymorphic Enum)
//public enum CampaignDetails: Codable, Sendable {
//    case banner(BannerDetails)
//    case floater(FloaterDetails)
//    case pip(PipDetails)
//    case csat(CsatDetails)
//    case survey(SurveyDetails)
//    case widget(WidgetDetails)
//    case bottomSheet(BottomSheetDetails)
//    case tooltip(TooltipDetails)
//    case modal(ModalDetails)
//    case stories([StoryDetails])
//    case reel(ReelDetails)
//    case unknown
//    
//    // Custom decoding based on campaign_type
//    public init(from decoder: Decoder) throws {
//        // ✅ Get the full container to access campaign_type
//        let container = try decoder.container(keyedBy: ParentCodingKeys.self)
//        let type = try container.decode(String.self, forKey: .campaignType)
//        
//        // ✅ Now decode details
//        let detailsContainer = try container.nestedContainer(keyedBy: DetailsCodingKeys.self, forKey: .details)
//        
//        Logger.debug("🔍 Decoding campaign type: \(type)")
//        
//        switch type {
//        case "PIP":
//            let details = try PipDetails(from: detailsContainer.superDecoder())
//            Logger.debug("✅ Decoded PIP details: \(details.id ?? "no-id")")
//            self = .pip(details)
//        case "BAN":
//            self = .banner(try BannerDetails(from: detailsContainer.superDecoder()))
//        case "FLT":
//            self = .floater(try FloaterDetails(from: detailsContainer.superDecoder()))
//        case "CSAT":
//            self = .csat(try CsatDetails(from: detailsContainer.superDecoder()))
//        case "SUR":
//            self = .survey(try SurveyDetails(from: detailsContainer.superDecoder()))
//        case "WID":
//            self = .widget(try WidgetDetails(from: detailsContainer.superDecoder()))
//        case "BTS":
//            self = .bottomSheet(try BottomSheetDetails(from: detailsContainer.superDecoder()))
//        case "TTP":
//            self = .tooltip(try TooltipDetails(from: detailsContainer.superDecoder()))
//        case "MOD":
//            self = .modal(try ModalDetails(from: detailsContainer.superDecoder()))
//        case "STR":
//            let stories = try [StoryDetails](from: detailsContainer.superDecoder())
//            self = .stories(stories)
//        case "REEL":
//            self = .reel(try ReelDetails(from: detailsContainer.superDecoder()))
//        default:
//            Logger.warning("⚠️ Unknown campaign type: \(type)")
//            self = .unknown
//        }
//    }
//    
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        switch self {
//        case .banner(let details): try container.encode(details)
//        case .floater(let details): try container.encode(details)
//        case .pip(let details): try container.encode(details)
//        case .csat(let details): try container.encode(details)
//        case .survey(let details): try container.encode(details)
//        case .widget(let details): try container.encode(details)
//        case .bottomSheet(let details): try container.encode(details)
//        case .tooltip(let details): try container.encode(details)
//        case .modal(let details): try container.encode(details)
//        case .stories(let details): try container.encode(details)
//        case .reel(let details): try container.encode(details)
//        case .unknown: break
//        }
//    }
//    
//    enum ParentCodingKeys: String, CodingKey {
//        case campaignType = "campaign_type"
//        case details
//    }
//    
//    enum DetailsCodingKeys: String, CodingKey {
//        case details
//    }
//}
