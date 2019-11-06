// Copyright © 2019 Brad Howes. All rights reserved.

import os
import UIKit

/**
 A UITableViewCell that shows a recording name, its size, and optional controls to stop a recording
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

    public func setProgress(_ percentage: Float) {
        if let av = self.accessoryView as? CircularProgressBar {
            av.setProgress(percentage, animated: true)
        }
        else {
            let av = CircularProgressBar(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
            av.setProgress(percentage, animated: false)
            self.accessoryView = av
        }
    }

    /**
     Stop the active recording.
     */
    @objc public func stopRecording() {
        print("** stopRecording")
        NotificationCenter.default.post(name: stopRecordingRequest, object: nil)
    }
}
