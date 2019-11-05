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
public final class CloudUploader {
    public typealias Notifier = (Uploadable)->Void

    private lazy var log: OSLog = Logging.logger("cloud")

    /**
     Add a RecordingInfo to the upload queue, updating its state as it is uploaded.

     - parameter recordingInfo: the recording to upload
     */
    public func enqueue(_ item: Uploadable, notifier: Notifier? = nil) {
        os_log(.info, log: log, "add: %@", item.source.path)
        guard FileManager.default.hasCloudDirectory else { return }
        DispatchQueue.global(qos: .background).async { self.upload(item, notifier: notifier) }
        os_log(.info, log: log, "add: END")
    }

    private func upload(_ item: Uploadable, notifier: Notifier?) {
        os_log(.info, log: log, "copyToCloud: %@ -> %@", item.source.path, item.destination.path)

        do {
            // Remove anything that might already be at the destination URL. For instance, user can always upload
            // again.
            os_log(.debug, log: log, "trying FileManager.removeItem - %@", item.destination.path)
            try FileManager.default.removeItem(at: item.destination)
            os_log(.debug, log: log, "ok")
        }
        catch {
            os_log(.error, log: log, "failure: %@", error.localizedDescription)
        }

        // Create a monitor to report on the progress of the upload. Due to circular reference it will live on after we
        // go out of scope while there is an operation to monitor.
        let monitor = Monitor(item, notifier: notifier)

        do {
            // Attempt to upload the file
            os_log(.debug, log: log, "trying FileManager.copyItem %@ -> %@", item.source.path, item.destination.path)
            try FileManager.default.copyItem(at: item.source, to: item.destination)
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

        private let item: Uploadable
        private let notifier: Notifier?
        private let query: NSMetadataQuery
        private var observer: NSObjectProtocol?

        init(_ item: Uploadable, notifier: Notifier?) {
            self.item = item
            self.notifier = notifier

            // Build a query that will return periodic updates for the uploading progress.
            let query = NSMetadataQuery()
            query.predicate = NSPredicate(format: "(%K LIKE[CD] %@)", NSMetadataItemPathKey, item.destination.path)
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
            guard let metadata = items.firstObject as? NSMetadataItem else { return }
            for attrName in metadata.attributes {
                switch attrName {
                case NSMetadataUbiquitousItemPercentUploadedKey:
                    if let percent = metadata.value(forAttribute: attrName) as? NSNumber {
                        os_log(.debug, log: self.log, "progress - %f", percent.doubleValue)
                        item.uploaded(progress: percent.doubleValue)
                    }
                case NSMetadataUbiquitousItemIsUploadedKey:
                    if let value = metadata.value(forAttribute: attrName) as? NSNumber, value.boolValue {
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
            if uploaded {
                item.succeeded()
            }
            else {
                item.failed()
            }
    
            query.stop()
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil

            self.notifier?(item)
        }
    }
}
