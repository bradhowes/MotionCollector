// Copyright © 2019 Brad Howes. All rights reserved.

import os
import CoreData
import UIKit

private func formatterBuilder(format: String) -> DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = format
    return dateFormatter
}

private struct RecordingNameGenerator {

    fileprivate static let displayNameFormatter: DateFormatter = formatterBuilder(format: "yyyy-MM-dd HH:mm:ss")
    fileprivate static let fileNameFormatter: DateFormatter = formatterBuilder(format: "yyyyMMddHHmmss")

    fileprivate static let recordingsDir: URL = {
        let fileManager = FileManager.default
        let docDir = fileManager.localDocumentsDirectory
        try? fileManager.createDirectory(at: docDir, withIntermediateDirectories: true, attributes: nil)
        return docDir
    }()

    fileprivate static func recordingUrl(fileName: String) -> URL {
        return recordingsDir.appendingPathComponent(fileName)
    }

    let date = Date()
    lazy var fileType: String = "csv"
    lazy var displayName: String = RecordingNameGenerator.displayNameFormatter.string(from: date)
    lazy var fileName: String = "\(RecordingNameGenerator.fileNameFormatter.string(from: date)).\(fileType)"
}

/**
 Representation of a CoreData entry for a past or in-progress audio recording.
 */
public final class RecordingInfo: NSManagedObject {
    private lazy var log: OSLog = Logging.logger("recinf")

    fileprivate static let elaspedFormatter: DateFormatter = formatterBuilder(format: "mm:ss")

    private var begin: Date = Date()

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

    @NSManaged private var valuesBlob: Data

    public var values: [String] {
        get {
            let obj = try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(valuesBlob)
            return obj as! [String]
        }
    }

    /// The current state of the recording
    public private(set) var state: State = .done

    /**
     Obtain a text representation of the recording duration.

     The format is `[[Hh] Mm] Ss` where the uppercase letters
     represent numeric values and the lowercase letters represent units. The `h` and `m` units only appear when
     necessary (eg. a duration of 103 seconds appears as "1m 43s")

     - TODO: localize units
     */
    public var formattedDuration: String {
        var elapsed = isRecording ? Date().timeIntervalSince(begin) : TimeInterval(duration)

        let hours = elapsed >= 3600.0 ? Int(elapsed / 3600.0) : 0
        elapsed -= Double(hours) * 3600.0

        let minutes = elapsed >= 60.0 ? Int(elapsed / 60.0) : 0
        elapsed -= Double(minutes) * 60.0

        let seconds = Int(elapsed.rounded())

        return (hours > 0 ? "\(hours) hours " : "") + (minutes > 0 ? "\(minutes) minute " : "") + "\(seconds)s"
    }

    /// The local (device) location of the recording
    public lazy var localUrl: URL = RecordingNameGenerator.recordingUrl(fileName: fileName)

    /// The (optional) location of the recording in the cloud
    public lazy var cloudURL: URL? = FileManager.default.cloudDocumentsDirectory?.appendingPathComponent(fileName)

    /// True if this instance is actively being recorded
    public var isRecording: Bool { return state == .recording }

    /// True when the recording is being uploaded to the cloud
    public var uploading: Bool { return state == .uploading }

    /// Obtain the current status of the recording
    public var status: String {
        switch state {
        case .recording: return "recording"
        case .done: return FileManager.default.hasCloudDirectory ? "waiting" : ""
        case .uploading: return "uploading"
        case .uploaded: return "uploaded"
        }
    }

    /// Class method that creates a new RecordingInfo entry in CoreData and returns a reference to it
    public class func insert() -> RecordingInfo {
        let recording: RecordingInfo = UIApplication.appDelegate.recordingInfoManagedContext!.insertObject()
        var namer = RecordingNameGenerator()
        recording.begin = namer.date
        recording.state = .recording
        recording.displayName = namer.displayName
        recording.fileName = namer.fileName
        recording.count = 0
        recording.uploadProgress = 0.0
        recording.uploaded = false
        recording.valuesBlob = Data()
        return recording
    }

    override public func awakeFromFetch() {
        os_log(.info, log: log, "awakeFromFetch")
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
    public func finishRecording(rows: [String]) {
        os_log(.info, log: log, "finishedRecording")

        DispatchQueue.global(qos: .background).async {
            let contents = rows.joined(separator: "\n") + "\n"
            os_log(.info, log: self.log, "contents: %s", contents)
            os_log(.info, log: self.log, "path: %s", self.localUrl.path)
            let ok = FileManager.default.createFile(atPath: self.localUrl.path,
                                                    contents: contents.data(using: .ascii),
                                                    attributes: nil)
            os_log(.info, log: self.log, "ok: %d", ok)
            if ok {
                self.beginUploading()
            }
        }

        self.managedObjectContext?.performChanges {
            self.count = Int64(rows.count)
            self.valuesBlob = try! NSKeyedArchiver.archivedData(withRootObject: rows, requiringSecureCoding: false)
            self.state = .done
            self.duration = Int64(Date().timeIntervalSince(self.begin).rounded())
        }
    }

    /**
     Begin uploading to the cloud (if supported)
     */
    public func beginUploading() {
        if FileManager.default.hasCloudDirectory {
            self.managedObjectContext?.performChanges {
                self.state = .uploading
                self.uploadProgress = 0.0
            }

            CloudReplicator.shared.add(recordingInfo: self)
        }
    }

    /**
     Record the current upload progress. The given value shall be between 0.0 and 100.0

     - parameter progress: percentage of the file that has been uploaded
     */
    public func uploaded(progress: Double) {
        guard state == .uploading else { return }
        self.uploadProgress = Float(progress) / 100.0
    }

    /**
     Uploading finished for this file. Update state.
     */
    public func endUploading() {
        self.managedObjectContext?.performChanges {
            self.state = .uploaded
            self.uploaded = true
        }
    }
}

extension RecordingInfo: Managed {
    public static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(key: #keyPath(displayName), ascending: false)]
    }
}
