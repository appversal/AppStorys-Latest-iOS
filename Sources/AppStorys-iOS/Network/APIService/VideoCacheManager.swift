//
//  VideoCacheManager.swift
//  AppStorys-iOS
//
//  Created by Darshika Gupta on 08/04/25.
//

import Foundation
import AVFoundation

@MainActor
final class VideoCacheManager : NSObject {
    static let shared = VideoCacheManager()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int = 500 * 1024 * 1024
    private var activeTasks: [URL: AVAssetDownloadTask] = [:]
    private var cachedVideoURLs: [URL: URL] = [:]
    private var cacheHits = 0
    private var cacheMisses = 0
    
    private override init() {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("VideoCache", isDirectory: true)
        super.init()
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            return
        }
        loadCachedVideos()
    }

    func cachedURLForVideo(originalURL: URL) -> URL {
        if let cachedURL = cachedVideoURLs[originalURL] {
            cacheHits += 1
            _ = Float(cacheHits) / Float(cacheHits + cacheMisses) * 100
            return cachedURL
        }
        
        cacheMisses += 1
        return originalURL
    }
    
    func isVideoCached(url: URL) -> Bool {
        return cachedVideoURLs[url] != nil
    }
    
    func cacheVideo(url: URL, completion: ((URL?) -> Void)? = nil) {
        if let cachedURL = cachedVideoURLs[url] {
            completion?(cachedURL)
            return
        }
    
        if activeTasks[url] != nil {
            completion?(nil)
            return
        }
        
        let filename = url.lastPathComponent
        let cachedURL = cacheDirectory.appendingPathComponent(filename)
        let asset = AVURLAsset(url: url)
        let assetDownloadURLSession = AVAssetDownloadURLSession(
            configuration: URLSessionConfiguration.background(withIdentifier: "com.reelsapp.videocache.\(UUID().uuidString)"),
            assetDownloadDelegate: self,
            delegateQueue: OperationQueue.main
        )

        
        let downloadTask = assetDownloadURLSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: filename,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 265_000])!
        
        activeTasks[url] = downloadTask
        tasks[downloadTask] = TaskInfo(sourceURL: url, destinationURL: cachedURL, completion: completion)
        downloadTask.resume()
    }
    
    func prefetchVideos(urls: [URL]) {
        for url in urls {
            if !isVideoCached(url: url) && activeTasks[url] == nil {
                cacheVideo(url: url)
            }
        }
    }
    func clearCache() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in cachedFiles {
                try fileManager.removeItem(at: file)
            }
            cachedVideoURLs.removeAll()
        } catch {
            return
        }

        cacheHits = 0
        cacheMisses = 0
    }
    private struct TaskInfo {
        let sourceURL: URL
        let destinationURL: URL
        let completion: ((URL?) -> Void)?
    }
    
    private var tasks: [AVAssetDownloadTask: TaskInfo] = [:]
    
    private func loadCachedVideos() {
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in cachedFiles {
                let filename = file.lastPathComponent
                if let url = URL(string: "https://example.com/videos/\(filename)") {
                    cachedVideoURLs[url] = file
                }
            }
        } catch {
            return
        }
    }
    
    private func checkCacheSize() {
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            var totalSize = 0
            var fileInfos = [(url: URL, size: Int, date: Date)]()
            
            for fileURL in cachedFiles {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let size = attributes[.size] as? Int,
                   let date = attributes[.modificationDate] as? Date {
                    totalSize += size
                    fileInfos.append((fileURL, size, date))
                }
            }
            
            if totalSize > maxCacheSize {
                fileInfos.sort { $0.date < $1.date }
                var removedCount = 0
                var removedSize = 0
                
                for fileInfo in fileInfos {
                    try fileManager.removeItem(at: fileInfo.url)
                    totalSize -= fileInfo.size
                    removedSize += fileInfo.size
                    removedCount += 1
                    for (key, value) in cachedVideoURLs {
                        if value == fileInfo.url {
                            cachedVideoURLs.removeValue(forKey: key)
                            break
                        }
                    }
                    if totalSize <= maxCacheSize * Int(0.8) {
                        break
                    }
                }
            }
        } catch {
            return
        }
    }
}

extension VideoCacheManager: @preconcurrency AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskInfo = tasks[assetDownloadTask] else {
            return
        }
        do {
            if fileManager.fileExists(atPath: taskInfo.destinationURL.path) {
                try fileManager.removeItem(at: taskInfo.destinationURL)
            }
            try fileManager.moveItem(at: location, to: taskInfo.destinationURL)
            cachedVideoURLs[taskInfo.sourceURL] = taskInfo.destinationURL
            
            let fileAttributes = try fileManager.attributesOfItem(atPath: taskInfo.destinationURL.path)
            if let fileSize = fileAttributes[.size] as? Int64 {
            }
            activeTasks.removeValue(forKey: taskInfo.sourceURL)
            tasks.removeValue(forKey: assetDownloadTask)
            DispatchQueue.main.async {
                taskInfo.completion?(taskInfo.destinationURL)
            }
            checkCacheSize()
        } catch {
            taskInfo.completion?(nil)
        }
    }
    
   func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {

        guard let taskInfo = tasks[assetDownloadTask] else { return }
        let duration = CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
        var downloadedDuration: Double = 0
        
        for value in loadedTimeRanges {
            let loadedTimeRange = value.timeRangeValue
            downloadedDuration += CMTimeGetSeconds(loadedTimeRange.duration)
        }
        
        let progress = (downloadedDuration / duration) * 100
    }
    
     func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? AVAssetDownloadTask,
              let taskInfo = tasks[downloadTask] else { return }

        if let error = error {
            DispatchQueue.main.async {
                taskInfo.completion?(nil)
            }
        }
        activeTasks.removeValue(forKey: taskInfo.sourceURL)
        tasks.removeValue(forKey: downloadTask)
    }
}

