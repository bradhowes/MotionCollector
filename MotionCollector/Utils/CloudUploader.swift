// Copyright © 2019 Brad Howes. All rights reserved.

import os
import UIKit
import CoreData

public protocol Uploadable: class {
    var source: URL { get }
    var destination: URL { get }

    func begin()
    func update(progress: Double)
    func end(_ uploaded: Bool)
}

/**
 Handle uploading of recordings to user's iCloud. The overall flow of this logic was heavily influenced by
 Amir Abbas Mousavian's FileProvider project (https://github.com/amosavian/FileProvider). In particular, the
 code in CloudFileProvider.swift that handles uploading of a file to iCloud with feedback on the progress.
 */
public final class CloudUploader {
    private lazy var log: OSLog = Logging.logger("cloud")

    static let shared: CloudUploader = CloudUploader()

    public typealias Notifier = () -> Void

    public var enabled: Bool {
        get { return _enabled && FileManager.default.hasCloudDirectory }
        set { _enabled = newValue }
    }

    private var _enabled: Bool = FileManager.default.hasCloudDirectory
    private var uploading: Bool = false
    private var availableObserver: NotificationObserver? = nil
    private var contextSavedObserver: NSObjectProtocol? = nil

    /**
     Construct new uploader to iCloud.
     */
    private init() {
        availableObserver = RecordingInfoManagedContext.shared.availableNotification.registerOnAny { self.contextAvailable($0) }
    }

    private func contextAvailable(_ context: NSManagedObjectContext) {

        // Monitor when the context has been saved. We restart the upload check in case there are any new uploads
        // to process.
        contextSavedObserver = context.addContextDidSaveNotificationObserver { _ in self.startUploads() }
        startUploads()
    }

    /**
     Begin uploading documents to iCloud.
     */
    public func startUploads() {
        guard enabled && !uploading else { return }
        os_log(.info, log: log, "startUploads")
        uploading = true
        uploadNext()
    }

    /**
     Stop uploading documents to iCloud. Anything that is currently being uploaded will continue to do so.
     */
    public func stopUploads() {
        os_log(.info, log: log, "stopUploads")
        uploading = false
    }

    private func uploadNext() {
        os_log(.info, log: log, "uploadNext")
        guard uploading else { return }
        DispatchQueue.global(qos: .background).async {
            guard let item = RecordingInfo.nextToUpload else {
                self.stopUploads()
                return
            }

            item.begin()
            DispatchQueue.global(qos: .background).async { self.upload(item) { self.uploadNext() } }
        }
    }

    private func upload(_ item: Uploadable, notifier: @escaping Notifier) {
        os_log(.info, log: log, "upload: %@ -> %@", item.source.path, item.destination.path)

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

        os_log(.info, log: log, "upload: END")
    }

    /**
     Monitors the uploading progress from local device to iCloud.
     */
    private final class Monitor {
        private lazy var log: OSLog = Logging.logger("mon")

        private let item: Uploadable
        private let notifier: Notifier
        private let query: NSMetadataQuery
        private var observer: NSObjectProtocol?

        init(_ item: Uploadable, notifier: @escaping Notifier) {
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
                        item.update(progress: percent.doubleValue)
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
            item.end(uploaded)

            query.stop()
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil

            self.notifier()
        }
    }
}
