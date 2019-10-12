// Copyright © 2019 Brad Howes. All rights reserved.

import os
import UIKit

/**
 A UITableViewCell that shows a recording name, its siae, and optional controls to stop a recording
 or show the progress of an upload to iCloud.
 */
public final class RecordingInfoTableViewCell: UITableViewCell {

    /// The name of the recording
    @IBOutlet weak var name: UILabel!

    /// The recording size and state info
    @IBOutlet weak var size: UILabel!

    /// The color of the text for recorded entries
    @IBInspectable var normalTextColor: UIColor?

    /// The color of the text when entry is recording
    @IBInspectable var recordingTextColor: UIColor?

    /// An CircularProgressBar associated with the cell. Creates and installs a new one when necessary
    public var uploadProgressIndicator: CircularProgressBar {
        if let av = self.accessoryView as? CircularProgressBar {
            return av
        }

        let av = CircularProgressBar(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        av.setProgress(0.0, animated: false)
        self.accessoryView = av
        return av
    }

    /**
     Stop the active recording.
     */
    @objc public func stopRecording() {
        print("** stopRecording")
        NotificationCenter.default.post(name: stopRecordingRequest, object: nil)
    }
}
