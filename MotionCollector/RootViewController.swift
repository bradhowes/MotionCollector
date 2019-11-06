// RootViewController.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import os
import CoreData
import UIKit

/**
 The top-level `root` view controller in the application.
 */
public final class RootViewController: UITabBarController {

    private var observer: NotificationObserver?
    private var ready: Bool = false

    /**
     Initially, recording and recording manipulation are disabled. Enable these features when there is a valid
     managed context available.
     */
    public override func viewDidLoad() {
        self.delegate = self
        super.viewDidLoad()
        observer = RecordingInfoManagedContext.shared.availableNotification.registerOnMain { _ in
            self.tabBar.items?.forEach { $0.isEnabled = true }
            self.selectedIndex = 0
            self.ready = true
        }
    }
}

extension RootViewController: UITabBarControllerDelegate {

    public func tabBarController(_ tabBarController: UITabBarController,
                                 shouldSelect viewController: UIViewController) -> Bool {
        return ready
    }
}

extension RootViewController {

    /**
     Show a Share popup sheet that offers ways to share a recording file.

     - parameter file: the recording to share
     - parameter actionFrom: the view where the share request originated from
     - parameter completion: closure to run when the presentation is done
     */
    public func share(file: URL, actionFrom: UIView, completion: @escaping ()->Void) {
        let objectsToShare = [file]
        let controller = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)

        let vc = self.presentedViewController != nil ? self.presentedViewController! : self
        controller.modalPresentationStyle = .popover
        vc.present(controller, animated: true, completion: completion)

        if let presentationController = controller.popoverPresentationController {
            presentationController.sourceView = actionFrom
            presentationController.sourceRect = actionFrom.frame
        }
    }
}
