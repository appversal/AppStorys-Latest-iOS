//import Combine
//import SwiftUI
//
//@MainActor
//final class WidgetViewModel: ObservableObject {
//
//    @Published var images: [WidgetImage] = []
//    @Published var widgetHeight: CGFloat = 150
//    @Published var selectedIndex = 0
//
//    private let apiService: APIServiceTwo
//    private let widgetCampaignType = "WID"
//
//
//    private var cancellables: Set<AnyCancellable> = []
//    private var campaignID: String?
//
//    init(apiService: APIServiceTwo) {
//            self.apiService = apiService
//            setupBindings()
//            loadWidgetCampaign()
//        }
//
//    private func setupBindings() {
//        $selectedIndex.sink { [weak self] index in
//            self?.didViewWidgetImage(at: index)
//        }
//        .store(in: &cancellables)
//    }
//
//    private func loadWidgetCampaign() {
//        Task {
//            // Call API to fetch campaigns
//            await apiService.appstorys(appID: "1163a1a2-61a8-486c-b263-7252f9a502c2", accountID: "5bb1378d-9f32-4da8-aed1-1ee44d086db7", userID: "gjkgmkgnff")
//            
//            // Wait for campaigns to be available
//            guard let widgetCampaign = apiService.widgetCampaigns.first else {
//                print("❌ No widget campaign found")
//                return
//            }
//            
//            self.campaignID = widgetCampaign.id
//            
//            guard case let .widget(details) = widgetCampaign.details else {
//                print("❌ Invalid campaign details")
//                return
//            }
//            
//            let widgetHeight = CGFloat(details.height ?? 150)
//            let images = details.widgetImages.sorted { $0.order < $1.order }
//
//            await MainActor.run {
//                self.widgetHeight = widgetHeight
//                self.images = images
//                self.didViewWidgetImage(at: 0)
//            }
//        }
//    }
//
////    func viewDidLoad() {
////        Task {
////            do {
////                let validatedAccount = try await apiService.validateAccount(appID: appID, accountID: accountID)
////                guard validatedAccount else {
////                    return
////                }
////
////                let campaignList = try await apiService.getCampaignList(forScreen: screenName, position: position)
////                let campaigns = try await apiService.getCampaigns(campaignList: campaignList)
////
////                guard let widgetCampaign = campaigns.first(where: {$0.campaignType == widgetCampaignType }) else { return
////                }
////                self.campaignID = widgetCampaign.id
////                guard let campaignDetails =  widgetCampaign.details.details else { return }
////                let widgetHeight = CGFloat(campaignDetails.height ?? 0)
////                let images = campaignDetails.widgetImages.sorted { $0.order < $1.order }
////
////                await MainActor.run { [weak self ] in
////                    self?.widgetHeight = widgetHeight
////                    self?.images = images
////                    self?.didViewWidgetImage(at: 0)
////                }
////            } catch {
////                print(error)
////            }
////        }
////    }
//
//    func didViewWidgetImage(at index: Int) {
//        guard let campaignID, let viewedImage = images[safe: index] else { return }
//        Task {
//            try await apiService.trackAction(type: .view,  campaignID: campaignID, widgetID: viewedImage.id)
//        }
//    }
////
////    func didTapWidgetImage(at index: Int) {
////        guard let campaignID, let tappedImage = images[safe: index] else { return }
////        Task {
////            try await apiService.trackAction(type: .click, userID: appID, campaignID: campaignID, widgetID: tappedImage.id)
////        }
////    }
//}
//
extension Collection {
    // Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
