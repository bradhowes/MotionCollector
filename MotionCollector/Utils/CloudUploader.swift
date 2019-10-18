// Copyright © 2019 Brad Howes. All rights reserved.

import os
import UIKit

public protocol Uploadable: class {
    var source: URL { get }
    var destination: URL { get }

    func uploaded(progress: Double)
    func succeeded()
    func failed()
}

/**
 Handle uploading of recordings to user's iCloud. The overall flow of this logic was heavily influenced by
 Amir Abbas Mousavian's FileProvider project (https://github.com/amosavian/FileProvider). In particular, the
 code in CloudFileProvider.swift that handles uploading of a file to iCloud with feedback on the progress.
 */
public final class CloudUploader<Uploadable> {

    private lazy var log: OSLog = Logging.logger("cloud")

    /**
     Add a RecordingInfo to the upload queue, updating its state as it is uploaded.

     - parameter recordingInfo: the recording to upload
     */
    public func add(recordingInfo: RecordingInfo) {
        os_log(.info, log: log, "add: %@", recordingInfo.localUrl.absoluteString)
        guard FileManager.default.hasCloudDirectory else { return }
        DispatchQueue.global(qos: .background).async {
            self.copyTo(url: recordingInfo.cloudURL!, recordingInfo: recordingInfo)
        }
        os_log(.info, log: log, "add: END")
    }

    private func copyTo(url: URL, recordingInfo: RecordingInfo) {
        os_log(.info, log: log, "copyToCloud: %@ -> %@", recordingInfo.localUrl.absoluteString, url.absoluteString)

        do {
            // Remove anything that might already be at the destination URL. For instance, user can always upload
            // again.
            os_log(.debug, log: log, "trying FileManager.removeItem - %@", url.absoluteString)
            try FileManager.default.removeItem(at: url)
            os_log(.debug, log: log, "ok")
        }
        catch {
            os_log(.error, log: log, "failure: %@", error.localizedDescription)
        }

        // Create a monitor to report on the progress of the upload. Due to circular reference it will live on after we
        // go out of scope while there is an operation to monitor.
        let monitor = Monitor(recordingInfo: recordingInfo)

        do {
            // Attempt to upload the file
            os_log(.debug, log: log, "trying FileManager.copyItem %@ -> %@", recordingInfo.localUrl.absoluteString,
                   url.absoluteString)
            try FileManager.default.copyItem(at: recordingInfo.localUrl, to: url)
            os_log(.debug, log: log, "ok")
        }
        catch {
            os_log(.error, log: log, "failure: %@", error.localizedDescription)

            // Error attempting to copy -- nothing to monitor.
            monitor.finalize(uploaded: false)
        }

        os_log(.info, log: log, "copyToCloud: END")
    }

    /**
     Monitors the uploading progress from local device to iCloud.
     */
    private class Monitor {
        private lazy var log: OSLog = Logging.logger("mon")

        private let recordingInfo: RecordingInfo
        private let query: NSMetadataQuery
        private var observer: NSObjectProtocol?

        init(recordingInfo: RecordingInfo) {
            self.recordingInfo = recordingInfo

            // Build a query that will return periodic updates for the uploading progress.
            let query = NSMetadataQuery()
            query.predicate = NSPredicate(format: "(%K LIKE[CD] %@)", NSMetadataItemPathKey, recordingInfo.cloudURL!.path)
            query.valueListAttributes = [NSMetadataUbiquitousItemPercentUploadedKey, NSMetadataUbiquitousItemIsUploadedKey]
            query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            self.query = query

            // Make ourselves the observer for the query changes. Note that this will create a circular reference, but
            // this is what we want. The circular reference is broken in our `finalize` method.
            self.observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query,
                                                                   queue: .main) { self.notification($0) }
            DispatchQueue.main.async { query.start() }
        }

        private func notification(_ notification: Notification) {
            os_log(.debug, log: self.log, "notification")
            guard let items = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? NSArray else { return }
            guard let item = items.firstObject as? NSMetadataItem else { return }
            for attrName in item.attributes {
                switch attrName {
                case NSMetadataUbiquitousItemPercentUploadedKey:
                    if let percent = item.value(forAttribute: attrName) as? NSNumber {
                        os_log(.debug, log: self.log, "progress - %f", percent.doubleValue)
                        recordingInfo.uploaded(progress: percent.doubleValue)
                    }
                case NSMetadataUbiquitousItemIsUploadedKey:
                    if let value = item.value(forAttribute: attrName) as? NSNumber, value.boolValue {
                        finalize(uploaded: true)
                    }
                default:
                    break
                }
            }
        }

        internal func finalize(uploaded: Bool) {
            os_log(.debug, log: self.log, "finalize - %d", uploaded)
            guard let observer = self.observer else { return }
            recordingInfo.endUploading(uploaded)
            query.stop()
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}
