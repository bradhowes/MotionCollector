// Copyright © 2019 Brad Howes. All rights reserved.

import os
import CoreData
import UIKit

/**
 Representation of a CoreData entry for a past or in-progress audio recording.
 */
public final class RecordingInfo: NSManagedObject {
    private lazy var log: OSLog = Logging.logger("recinf")

    /**
     The state of the recording instance.

     All recordings start out in `recording` state until they are stopped, which
     puts them in the `done` state. If uploading to a cloud storage is supported and enabled, and the file is being
     uploaded, it moves to the `uploading` state. Finally, if an upload completes, the state finally reaches the
     `uploaded` state.
     */
    public enum State: Int64 {
        case recording = 0
        case done = 1
        case uploading = 2
        case uploaded = 3
        case failed = 4
    }

    /// The current state of the recording
    public private(set) var state: State = .done {
        didSet { self.rawState = state.rawValue }
    }

    /// The name of the recording to show in the UI
    @NSManaged public private(set) var displayName: String

    /// The file name of the recording on the device (and in the cloud)
    @NSManaged public private(set) var fileName: String

    /// The duration of the recoding in seconds
    @NSManaged private var duration: Int64

    /// The size of the recording in rows
    @NSManaged public private(set) var count: Int64

    /// True if the file has been uploaded to a cloud storage.
    @NSManaged public private(set) var uploaded: Bool

    /// The amount of the file that has been uploaded (0.0 - 1.0)
    @NSManaged public private(set) var uploadProgress: Float

    /// The duration of the recording formatted as HH:MM:SS
    public var formattedDuration: String {
        let duration = isRecording ? Date().timeIntervalSince(beginTimestamp) : TimeInterval(self.duration)
        return Formatters.formatted(duration: duration)
    }

    /// The local (device) location of the recording
    public lazy var localUrl: URL = RecordingNameGenerator.recordingUrl(fileName: fileName)

    /// The (optional) location of the recording in the cloud
    public lazy var cloudURL: URL? = FileManager.default.hasCloudDirectory ?
        FileManager.default.cloudDocumentsDirectory?.appendingPathComponent(fileName) : nil

    /// True if this instance is actively being recorded
    public var isRecording: Bool { return state == .recording }

    /// True when the recording is being uploaded to the cloud
    public var uploading: Bool { return state == .uploading }

    /// Obtain the current status of the recording
    public var status: String { Formatters.formatted(recordingStatus: self.state) }

    @NSManaged private var rawState: Int64
    private var beginTimestamp: Date = Date()

    /// Class method that creates a new RecordingInfo entry in CoreData and returns a reference to it
    public class func create() -> RecordingInfo {
        let recording: RecordingInfo = RecordingInfoManagedContext.shared.newObject
        var namer = RecordingNameGenerator()
        recording.beginTimestamp = namer.date
        recording.state = .recording
        recording.displayName = namer.displayName
        recording.fileName = namer.fileName
        recording.count = 0
        recording.uploadProgress = 0.0
        recording.uploaded = false
        return recording
    }

    /**
     Instance is being reconstituted from Core Data storage. Make it have a valid `state` value.
     */
    override public func awakeFromFetch() {
        os_log(.info, log: log, "awakeFromFetch")
        super.awakeFromFetch()
        self.state = self.uploaded ? .uploaded : .done
    }

    /**
     Set a new file size (bytes) value for the recording.

     - parameter size: the new size in bytes
     */
    public func update(count: Int) {
        precondition(state == .recording)
        os_log(.info, log: log, "update")
        managedObjectContext?.performChanges { self.count = Int64(count) }
    }

    /**
     Remove the CoreData entry for this recording.
     */
    public func delete() {
        os_log(.info, log: log, "delete")
        managedObjectContext?.performChanges { self.managedObjectContext?.delete(self) }
    }

    /**
     Stop recording into the file held by this instance.
     */
    public func finishRecording(rows: [Datum]) {
        os_log(.info, log: log, "finishedRecording")

        DispatchQueue.global(qos: .background).async {
            let contents = rows.text
            os_log(.info, log: self.log, "contents: %s", contents)
            os_log(.info, log: self.log, "path: %s", self.localUrl.path)
            let ok = FileManager.default.createFile(atPath: self.localUrl.path,
                                                    contents: contents.data(using: .ascii),
                                                    attributes: nil)
            os_log(.info, log: self.log, "ok: %d", ok)

            self.managedObjectContext?.performChanges {
                self.state = ok ? .done : .failed
                self.uploaded = false
                self.count = Int64(rows.count)
                self.duration = Int64(Date().timeIntervalSince(self.beginTimestamp).rounded())
            }
        }
    }

    /**
     Reset the `uploaded` state of this instance so that it will be uploaded again.
     */
    public func clearUploaded() {
        self.managedObjectContext?.performChanges {
            self.state = .done
            self.uploaded = false
        }
    }
}

// MARK: - Uploadable Protocol

extension RecordingInfo: Uploadable {

    /// The location of the recording file on the device.
    public var source: URL { self.localUrl }

    /// The location of the recording file in iCloud. This is only valid when iCloud is enabled on the device.
    public var destination: URL { self.cloudURL! }

    /**
     Begin uploading to the cloud
     */
    public func begin() {
        precondition(state == .done)
        guard FileManager.default.hasCloudDirectory else { return }
        self.managedObjectContext?.performChanges {
            self.state = .uploading
            self.uploadProgress = 0.0
        }
    }

    /**
     Uploading finished for this file. Update state.
     */
    public func end(_ uploaded: Bool) {
        self.managedObjectContext?.performChanges {
            self.state = uploaded ? .uploaded : .failed
            self.uploaded = uploaded
        }
    }

    /**
     Record the current upload progress. The given value shall be between 0.0 and 100.0

     - parameter progress: percentage of the file that has been uploaded
     */
    public func update(progress: Double) {
        guard state == .uploading else { return }
        self.uploadProgress = Float(progress) / 100.0
    }
}

// MARK: - Managed Protocol

extension RecordingInfo: Managed {

    public static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(key: #keyPath(displayName), ascending: false)]
    }

    /// Obtain the next instance that is ready to be uploaded to iCloud
    public static var nextToUpload: Uploadable? {
        guard CloudUploader.shared.enabled else { return nil }
        guard let context = RecordingInfoManagedContext.shared.context else { return nil }
        let predicate = NSPredicate(format: "uploaded == false && count > 0 && rawState == \(State.done.rawValue)")
        return findOrFetch(in: context, matching: predicate)
    }
}
