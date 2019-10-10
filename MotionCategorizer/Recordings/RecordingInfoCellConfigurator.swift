// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit

struct RecordingInfoCellConfigurator {

    /**
     Business logic for showing the contents of a RecordingInfo instance in a RecordingInfoTableViewCell

     - parameter cell: the RecordingInfoTableViewCell to render into
     - parameter recordingInfo: the RecordingInfo model to render
     */
    static func configure(cell: RecordingInfoTableViewCell, with recordingInfo: RecordingInfo) {

        let bgColorView = UIView()
        bgColorView.backgroundColor = .darkGray
        cell.selectedBackgroundView = bgColorView

        cell.name.text = recordingInfo.displayName

        let sizeText = recordingInfo.status.isEmpty
            ? "\(recordingInfo.formattedDuration) - \(recordingInfo.count)"
            : "\(recordingInfo.formattedDuration) - \(recordingInfo.count) - \(recordingInfo.status)"

        cell.size.text = sizeText

        if recordingInfo.isRecording {
            let stop = UIButton(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            stop.setTitle("Stop", for: .normal)
            stop.setTitleColor(.red, for: .normal)
            stop.frame.size = stop.sizeThatFits(CGSize.zero)
            stop.addTarget(cell, action: #selector(RecordingInfoTableViewCell.stopRecording), for: .touchUpInside)
            cell.accessoryView = stop
        }
        else if recordingInfo.uploading == true {
            let percentage = recordingInfo.uploadProgress
            cell.uploadProgressIndicator.setProgress(percentage, animated: true)
        }
        else {
            cell.accessoryView = nil
        }
    }

    /**
     Create actions for a row when user swipes left-to-right.

     - parameter indexPath: index of the row to work on
     - parameter recordingInfo: the RecordingInfo instance associated with the row
     - parameter cell: the UITableViewCell instance associated with the row
     - returns: optional collection of UIContextualAction instances that describe the actions for the row
     */
    static public func makeLeadingSwipeActions(at indexPath: IndexPath, with recordingInfo: RecordingInfo,
                                               cell: UITableViewCell?) -> UISwipeActionsConfiguration? {
        guard let cell = cell, !recordingInfo.isRecording else { return nil }

        var actions = [UIContextualAction]()
        if !recordingInfo.uploading {
            actions.append(makeUploadAction(with: recordingInfo))
        }

        if let shareAction = makeShareAction(at: indexPath, with: recordingInfo, cell: cell) {
            actions.append(shareAction)
        }

        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false

        return config
    }

    /**
     Create actions for a row when user swipes right-to-left.

     - parameter vc: the active UIViewController
     - parameter indexPath: index of the row to work on
     - parameter recordingInfo: the RecordingInfo instance associated with the row
     - returns: optional collection of UIContextualAction instances that describe the actions for the row
     */
    static public func makeTrailingSwipeActions(vc: UIViewController, at indexPath: IndexPath,
                                                with recordingInfo: RecordingInfo) -> UISwipeActionsConfiguration? {
        guard !recordingInfo.isRecording else { return nil }

        let config = UISwipeActionsConfiguration(actions: [makeDeleteAction(vc: vc, with: recordingInfo)])
        config.performsFirstActionWithFullSwipe = false
        return config
    }

    static private var mainWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
        else {
            return UIApplication.shared.keyWindow
        }
    }

    static private func makeShareAction(at indexPath: IndexPath, with recordingInfo: RecordingInfo,
                                        cell: UITableViewCell) -> UIContextualAction? {
        guard let rvc = mainWindow?.rootViewController as? RootViewController else {
            fatalError("nil UITabBarControllerl")
        }

        guard !recordingInfo.isRecording else { return nil }

        let share = UIContextualAction(style: .normal, title: "Share") { action, view, completion in
            rvc.share(recordingInfo: recordingInfo, actionFrom: cell) {
                completion(true)
            }
        }

        share.image = UIImage(named: "share")
        share.backgroundColor = UIColor.blue

        return share
    }

    static private func makeUploadAction(with recordingInfo: RecordingInfo) -> UIContextualAction {
        let upload = UIContextualAction(style: .normal, title: "Upload") { action, view, completion in
            recordingInfo.beginUploading()
            completion(true)
        }

        upload.image = UIImage(named: "upload")
        upload.backgroundColor = UIColor.orange

        return upload
    }

    static private func makeDeleteAction(vc: UIViewController, with recordingInfo: RecordingInfo) -> UIContextualAction {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            let prompt = UIAlertController(title: "Delete Recording?",
                                           message: """
    Deleting the recording will permanently remove it from this device, but any copies stored in iCloud will
    still exist.
    """,
                                           preferredStyle: .alert)
            prompt.addAction(UIAlertAction(title: "Delete", style: .destructive) { action in
                recordingInfo.delete()
                completion(true)
            })
            prompt.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
                completion(false)
            })

            vc.present(prompt, animated: true, completion: nil)
        }

        delete.backgroundColor = UIColor.red
        delete.image = UIImage(named: "trash")

        return delete
    }
}
