// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit

class Formatters {

    static let shared: Formatters = Formatters()

    private init() {}

    private let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    public func formatted(duration: TimeInterval) -> String {
        return formatter.string(from: duration)!
    }

    private lazy var formatString = NSLocalizedString(
        "records count", comment: "records count string format in Localized.stringsdict")

    public func formatted(recordCount: Int) -> String {
        return String.localizedStringWithFormat(formatString, recordCount)
    }

    private lazy var recordingLabel = NSLocalizedString("recording", comment: "actively recording data")
    private lazy var waitingLabel = NSLocalizedString("waiting", comment: "waiting to upload file to iCloud")
    private lazy var uploadingLabel = NSLocalizedString("uploading", comment: "actively uploading file to iCloud")
    private lazy var uploadedLabel = NSLocalizedString("uploaded", comment: "previously uploaded to iCloud")
    private lazy var failedLabel = NSLocalizedString("failed", comment: "last attempt to upload to iCloud failed")

    public func formatted(recordingStatus: RecordingInfo.State) -> String {
        switch recordingStatus {
        case .recording: return recordingLabel
        case .done: return (FileManager.default.hasCloudDirectory && UIApplication.appDelegate.uploadsEnabled) ? waitingLabel : ""
        case .uploading: return uploadingLabel
        case .uploaded: return uploadedLabel
        case .failed: return failedLabel
        }
    }
}
