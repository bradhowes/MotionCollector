// CloudReplicator.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import os
import UIKit

/**
 Handle uploading of recordings to user's iCloud
 */
public final class CloudReplicator {

    private lazy var log: OSLog = Logging.logger("cloud")

    private let workQueue: DispatchQueue

    static var shared: CloudReplicator = CloudReplicator()

    private init() {
        self.workQueue = DispatchQueue.global(qos: .background)
    }

    /**
     Add a RecordingInfo to the upload queue, updating its state as it is uploaded.

     - parameter recordingInfo: the recording to upload
     */
    public func add(recordingInfo: RecordingInfo) {
        os_log(.info, log: log, "add: %@", recordingInfo.localUrl.absoluteString)

        guard FileManager.default.hasCloudDirectory else { return }
        workQueue.async { [weak self] in
            if let wself = self {
                wself.copyToCloud(recordingInfo: recordingInfo)
            }
        }
        os_log(.info, log: log, "add: END")
    }

    private func copyToCloud(recordingInfo: RecordingInfo) {
        os_log(.info, log: log, "copyToCloud: %@", recordingInfo.localUrl.absoluteString)

        let fileManager = FileManager.default
        if let cloudUrl = recordingInfo.cloudURL {
            monitorTransmissionProgress(url: cloudUrl, recordingInfo: recordingInfo)
            do {
                // Remove anything that might already be there in the destination.
                os_log(.debug, log: log, "trying FileManager.removeItem")
                try fileManager.removeItem(at: cloudUrl)
                os_log(.debug, log: log, "ok")
            }
            catch {
                os_log(.error, log: log, "failure: %@", error.localizedDescription)
            }

            do {
                os_log(.debug, log: log, "trying FileManager.copyItem")
                try fileManager.copyItem(at: recordingInfo.localUrl, to: cloudUrl)
                os_log(.debug, log: log, "ok")
            }
            catch {
                os_log(.error, log: log, "failure: %@", error.localizedDescription)
            }
        }

        os_log(.info, log: log, "copyToCloud: END")
    }

    private func monitorTransmissionProgress(url: URL, recordingInfo: RecordingInfo) {
        os_log(.info, log: log, "monitorTransmissionProgress: %@ %@", url.absoluteString,
               recordingInfo.localUrl.absoluteString)

        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "(%K LIKE[CD] %@)", NSMetadataItemPathKey, url.path)
        query.valueListAttributes = [NSMetadataUbiquitousItemPercentUploadedKey, NSMetadataUbiquitousItemIsUploadedKey]
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query,
                                                          queue: .main) { [weak self] (notification) in
            guard let items = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? NSArray,
                let item = items.firstObject as? NSMetadataItem,
                let wself = self else {
                    return
            }

            func updateProgress(_ percent: Double) {
                os_log(.debug, log: wself.log, "uploaded %f", percent)
                recordingInfo.uploaded(progress: percent)
                if percent >= 100.0 {
                    os_log(.debug, log: wself.log, "uploading done")
                    recordingInfo.endUploading()
                    guard let obs = observer else { return }
                    query.stop()
                    NotificationCenter.default.removeObserver(obs)
                    observer = nil
                }
            }

            for attrName in item.attributes {
                switch attrName {
                case NSMetadataUbiquitousItemPercentUploadedKey:
                    guard let percent = item.value(forAttribute: attrName) as? NSNumber else { break }
                    updateProgress(percent.doubleValue)
                case NSMetadataUbiquitousItemIsUploadedKey:
                    if let value = item.value(forAttribute: attrName) as? NSNumber, value.boolValue {
                        updateProgress(100)
                    }
                default:
                    break
                }
            }
        }

        DispatchQueue.main.async {
            query.start()
        }
    }
}
