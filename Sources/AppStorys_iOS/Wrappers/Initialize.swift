//
//  Initialize.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//
import SwiftUI

public extension AppStorys {
    
    // MARK: - SDK Initialization (Static Methods)
    
    /// Initializes the AppStorys SDK
    /// - Parameters:
    ///   - accountID: Your AppStorys account ID
    ///   - appID: Your AppStorys app ID
    ///   - userID: Current user identifier
    ///   - baseURL: Optional custom base URL (defaults to production)
    ///
    /// Example:
    /// ```swift
    /// .task {
    ///     await AppStorys.initialize(
    ///         accountID: "your-account-id",
    ///         appID: "your-app-id",
    ///         userID: "user123"
    ///     )
    /// }
    /// ```
    static func initialize(
        accountID: String,
        appID: String,
        userID: String,
        baseURL: String = "https://users.appstorys.com"
    ) async {
        await shared.appstorys(
            accountID: accountID,
            appID: appID,
            userID: userID,
            baseURL: baseURL
        )
    }
}
