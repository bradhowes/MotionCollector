// RootViewController.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import os
import CoreData
import UIKit

/**
 The top-level `root` view controller in the application.
 */
final class RootViewController: UITabBarController {

    private var observer: NotificationObserver?

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Disable tab switching until Core Data context is available.
        self.tabBar.isUserInteractionEnabled = false
        observer = RecordingInfoManagedContext.shared.availableNotification.registerOnMain { _ in
            self.tabBar.isUserInteractionEnabled = true
            self.observer = nil
        }
    }
}

extension RootViewController {

    /**
     Show a Share popup sheet that offers ways to share a recording file.

     - parameter file: the recording to share
     - parameter actionFrom: the view where the share request originated from
     - parameter completion: closure to run when the presentation is done
     */
    public func share(file: URL, actionFrom: UIView, completion: @escaping () -> Void) {
        let objectsToShare = [file]
        let controller = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)

        let pvc = self.presentedViewController != nil ? self.presentedViewController! : self
        controller.modalPresentationStyle = .popover
        pvc.present(controller, animated: true, completion: completion)

        if let presentationController = controller.popoverPresentationController {
            presentationController.sourceView = actionFrom
            presentationController.sourceRect = actionFrom.frame
        }
    }
}
