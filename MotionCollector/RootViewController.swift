// RootViewController.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import os
import CoreData
import UIKit

/**
 The top-level `root` view controller in the application.
 */
public final class RootViewController: UITabBarController {

    private var recordingInfoManagedContextLoaderObserver: NotificationObserver?

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Invoke `injectManagedObjectContext` when the CoreData managed object context is available for
        // `RecordingInfo` instances.
        recordingInfoManagedContextLoaderObserver = RecordingInfoManagedContext.registerLoadedNotifier {
            self.injectManagedObjectContext($0)
        }
    }

    /**
     Inject an NSManagedObjectContext instance into the `RecordingsViewController` instance.

     - parameter managedObjectContext: the NSManagedObjectContext to inject
     */
    public func injectManagedObjectContext(_ managedObjectContext: NSManagedObjectContext) {
        guard let vcs = self.viewControllers else {
            fatalError("expected to find collection of UIViewController instances")
        }

        // Look for the `RecordingsTableViewController` to inject into.
        for (index, vc) in vcs.enumerated() {
            if let nc = vc as? UINavigationController {
                if let rvc = nc.topViewController as? RecordingsTableViewController {
                    rvc.tabBarItem.isEnabled = true
                    self.tabBar.items?[index].isEnabled = true
                }
            }
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
