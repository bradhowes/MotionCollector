// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit

public enum Formatters {

    /**
     Transform time interval into a String in the form HH:MM:SS.

     - parameter duration: time interval to format
     - returns: formatted value in HH:MM:SS
     */
    public static func formatted(duration: TimeInterval) -> String { Self.formatter.string(from: duration)! }

    /**
     Convert an integer record count into a string with a formatted unit value.

     - parameter recordCount: the value to format
     - returns: the formatted value
     */
    public static func formatted(recordCount: Int) -> String {
        String.localizedStringWithFormat(Self.formatString, recordCount)
    }

    /**
     Obtain a formatted status value.

     - parameter recordingStatus: the RecordingInfo state value to format
     - returns: the formatted value
     */
    public static func formatted(recordingStatus: RecordingInfo.State) -> String {
        switch recordingStatus {
        case .recording: return Self.recordingLabel
        case .done: return UIApplication.appDelegate.uploadsEnabled ? Self.waitingLabel : ""
        case .uploading: return Self.uploadingLabel
        case .uploaded: return Self.uploadedLabel
        case .failed: return Self.failedLabel
        }
    }

    /// Formatter for RecordingInfo displayed names
    public static let displayNameFormatter: DateFormatter = formatterBuilder(format: "yyyy-MM-dd HH:mm:ss")

    /// Formatter for RecordingInfo file names
    public static let fileNameFormatter: DateFormatter = formatterBuilder(format: "yyyyMMddHHmmss")
}

private extension Formatters {

    static let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    static let formatString = NSLocalizedString(
        "records count", comment: "records count string format in Localized.stringsdict")

    static let recordingLabel = NSLocalizedString("recording", comment: "actively recording data")
    static let waitingLabel = NSLocalizedString("waiting", comment: "waiting to upload file to iCloud")
    static let uploadingLabel = NSLocalizedString("uploading", comment: "actively uploading file to iCloud")
    static let uploadedLabel = NSLocalizedString("uploaded", comment: "previously uploaded to iCloud")
    static let failedLabel = NSLocalizedString("failed", comment: "last attempt to upload to iCloud failed")

    static func formatterBuilder(format: String) -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter
    }
}
