//
//  URLHelper.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/10/25.
//

import Foundation

enum URLHelper {
    /// Fix malformed URLs from backend
    static func sanitizeURL(_ urlString: String?) -> String? {
        guard let urlString = urlString, !urlString.isEmpty else {
            return nil
        }
        
        // Already has protocol
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        // Fix missing protocol and slash after domain
        var fixed = urlString
        
        // Fix cloudfront URLs: "d9sydtcsqik35.cloudfront.netpip/..." → "https://d9sydtcsqik35.cloudfront.net/pip/..."
        if fixed.contains("cloudfront.net") && !fixed.contains("cloudfront.net/") {
            fixed = fixed.replacingOccurrences(of: "cloudfront.net", with: "cloudfront.net/")
        }
        
        // Add https:// prefix
        if !fixed.hasPrefix("https://") {
            fixed = "https://" + fixed
        }
        
        return fixed
    }
}
