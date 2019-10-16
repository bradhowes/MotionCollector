// Copyright © 2019 Brad Howes. All rights reserved.

import os
import UIKit

/**
 Handle uploading of recordings to user's iCloud. The overall flow of this logic was heavily influenced by
 Amir Abbas Mousavian's FileProvider project (https://github.com/amosavian/FileProvider). In particular, the
 code in CloudFileProvider.swift that handles uploading of a file to iCloud with feedback on the progress.
 */
public final class CloudReplicator {

    private lazy var log: OSLog = Logging.logger("cloud")

    /// There is only one instance of this class
    static var shared: CloudReplicator = CloudReplicator()

    /**
     Add a RecordingInfo to the upload queue, updating its state as it is uploaded.

     - parameter recordingInfo: the recording to upload
     */
    public func add(recordingInfo: RecordingInfo) {
        os_log(.info, log: log, "add: %@", recordingInfo.localUrl.absoluteString)
        guard FileManager.default.hasCloudDirectory, let cloudURL = recordingInfo.cloudURL else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.copyTo(cloudURL: cloudURL, recordingInfo: recordingInfo)
        }
        os_log(.info, log: log, "add: END")
    }

    private func copyTo(cloudURL: URL, recordingInfo: RecordingInfo) {
        os_log(.info, log: log, "copyToCloud: %@", recordingInfo.localUrl.absoluteString)

        monitorTransmissionProgress(url: cloudURL, recordingInfo: recordingInfo)
        do {
            // Remove anything that might already be at the destination URL. For instance, user can always upload
            // again.
            os_log(.debug, log: log, "trying FileManager.removeItem")
            try FileManager.default.removeItem(at: cloudURL)
            os_log(.debug, log: log, "ok")
        }
        catch {
            os_log(.error, log: log, "failure: %@", error.localizedDescription)
        }

        do {
            // Attempt to upload the file
            os_log(.debug, log: log, "trying FileManager.copyItem")
            try FileManager.default.copyItem(at: recordingInfo.localUrl, to: cloudURL)
            os_log(.debug, log: log, "ok")
        }
        catch {
            os_log(.error, log: log, "failure: %@", error.localizedDescription)
        }

        os_log(.info, log: log, "copyToCloud: END")
    }

    private func monitorTransmissionProgress(url: URL, recordingInfo: RecordingInfo) {
        os_log(.info, log: log, "monitorTransmissionProgress: %@ %@", url.absoluteString,
               recordingInfo.localUrl.absoluteString)

        // Here is where the magic monitoring magic happens. Declare a new NSQuery which returns properties for
        // our upload file in the iCloud. We then register for any updates to the resuls from this NSPredicate.
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "(%K LIKE[CD] %@)", NSMetadataItemPathKey, url.path)
        query.valueListAttributes = [NSMetadataUbiquitousItemPercentUploadedKey, NSMetadataUbiquitousItemIsUploadedKey]
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        var observer: NSObjectProtocol?
        observer = NotificationCenter.default
            .addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self] (notification) in
                guard let obs = observer else { return }

                // Validate inputs and current state. If anything is off, stop future updates by releasing `observer`
                guard let items = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? NSArray,
                    let item = items.firstObject as? NSMetadataItem,
                    let wself = self else {
                        NotificationCenter.default.removeObserver(obs)
                        observer = nil
                        return
                }

                func updateProgress(_ percent: Double) {
                    os_log(.debug, log: wself.log, "uploaded %f", percent)
                    recordingInfo.uploaded(progress: percent)
                    if percent >= 100.0 {
                        os_log(.debug, log: wself.log, "uploading done")
                        recordingInfo.endUploading()
                        query.stop()
                        NotificationCenter.default.removeObserver(obs)
                        observer = nil
                    }
                }

                for attrName in item.attributes {
                    switch attrName {
                    case NSMetadataUbiquitousItemPercentUploadedKey:
                        if let percent = item.value(forAttribute: attrName) as? NSNumber {
                            updateProgress(percent.doubleValue)
                        }
                    case NSMetadataUbiquitousItemIsUploadedKey:
                        if let value = item.value(forAttribute: attrName) as? NSNumber, value.boolValue {
                            updateProgress(100)
                        }
                    default:
                        break
                    }
                }
        }

        DispatchQueue.main.async { query.start() }
    }
}
