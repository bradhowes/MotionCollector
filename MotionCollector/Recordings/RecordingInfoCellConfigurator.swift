// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit

public struct RecordingInfoCellConfigurator {

    /**
     Business logic for showing the contents of a RecordingInfo instance in a RecordingInfoTableViewCell

     - parameter cell: the RecordingInfoTableViewCell to render into
     - parameter recordingInfo: the RecordingInfo model to render
     */
    public static func configure(cell: RecordingInfoTableViewCell, with recordingInfo: RecordingInfo) {

        let bgColorView = UIView()
        bgColorView.backgroundColor = .darkGray
        cell.selectedBackgroundView = bgColorView

        cell.name.text = recordingInfo.displayName

        var bits = [
            recordingInfo.formattedDuration,
            Formatters.formatted(recordCount: Int(recordingInfo.count)),
        ]

        if !recordingInfo.status.isEmpty { bits.append(recordingInfo.status) }
        cell.size.text = bits.joined(separator: " - ")

        if recordingInfo.isRecording {
            let stop = UIButton(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            stop.setTitle("Stop", for: .normal)
            stop.setTitleColor(.red, for: .normal)
            stop.frame.size = stop.sizeThatFits(CGSize.zero)
            stop.addTarget(cell, action: #selector(RecordingInfoTableViewCell.stopRecording), for: .touchUpInside)
            cell.accessoryView = stop
        }
        else if recordingInfo.uploading {
            let percentage = recordingInfo.uploadProgress
            cell.setProgress(percentage)
        }
        else {
            cell.accessoryView = nil
        }
    }

    /**
     Create actions for a row when user swipes left-to-right.

     - parameter recordingInfo: the RecordingInfo instance associated with the row
     - parameter cell: the UITableViewCell instance associated with the row
     - returns: optional collection of UIContextualAction instances that describe the actions for the row
     */
    public static func makeLeadingSwipeActions(with recordingInfo: RecordingInfo,
                                               cell: UITableViewCell?) -> UISwipeActionsConfiguration? {
        guard let cell = cell, !recordingInfo.isRecording else { return nil }

        var actions = [UIContextualAction]()
        if !recordingInfo.uploading {
            actions.append(makeUploadAction(with: recordingInfo))
        }

        if let shareAction = makeShareAction(with: recordingInfo, cell: cell) {
            actions.append(shareAction)
        }

        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false

        return config
    }

    /**
     Create actions for a row when user swipes right-to-left.

     - parameter vc: the active UIViewController
     - parameter recordingInfo: the RecordingInfo instance associated with the row
     - returns: optional collection of UIContextualAction instances that describe the actions for the row
     */
    public static func makeTrailingSwipeActions(vc: UIViewController, deleteAction: @escaping ()->Void) -> UISwipeActionsConfiguration? {
        let config = UISwipeActionsConfiguration(actions: [makeDeleteAction(vc: vc, deleteAction: deleteAction)])
        config.performsFirstActionWithFullSwipe = true
        return config
    }
}

private extension RecordingInfoCellConfigurator {

    static var mainWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
        else {
            return UIApplication.shared.keyWindow
        }
    }

    static func makeShareAction(with recordingInfo: RecordingInfo, cell: UITableViewCell) -> UIContextualAction? {
        guard let rvc = mainWindow?.rootViewController as? RootViewController else {
            fatalError("nil RootViewController")
        }

        guard !recordingInfo.isRecording else { return nil }

        let share = UIContextualAction(style: .normal, title: "Share") { action, view, completion in
            rvc.share(file: recordingInfo.localUrl, actionFrom: cell) {
                completion(true)
            }
        }

        share.image = UIImage(named: "share")
        share.backgroundColor = UIColor.white

        return share
    }

    static func makeUploadAction(with recordingInfo: RecordingInfo) -> UIContextualAction {
        let upload = UIContextualAction(style: .normal, title: "Upload") { action, view, completion in
            recordingInfo.clearUploaded()
            completion(true)
        }

        upload.image = UIImage(named: "upload")
        upload.backgroundColor = UIColor.systemBlue

        return upload
    }

    static func makeDeleteAction(vc: UIViewController, deleteAction: @escaping ()->Void) -> UIContextualAction {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            let prompt = UIAlertController(title: "Delete Recording?",
                                           message: """
    Deleting the recording will permanently remove it from this device, but any copies stored in iCloud will
    still exist.
    """,
                                           preferredStyle: .alert)
            prompt.addAction(UIAlertAction(title: "Delete", style: .destructive) { action in
                deleteAction()
                completion(true)
            })
            prompt.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
                completion(false)
            })

            vc.present(prompt, animated: true, completion: nil)
        }

        delete.backgroundColor = UIColor.systemRed
        delete.image = UIImage(named: "trash")

        return delete
    }
}
