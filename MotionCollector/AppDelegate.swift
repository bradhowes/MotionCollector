//
//  AppDelegate.swift
//  MotionCategorizer
//
//  Created by Brad Howes on 10/8/19.
//  Copyright © 2019 Brad Howes. All rights reserved.
//

import os
import UIKit
import CoreData

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    lazy var log = Logging.logger("app")

    private let cloudUploader = CloudUploader.shared // Do this to force creation of instance ASAP

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after
        // application:didFinishLaunchingWithOptions. Use this method to release any resources that were specific to
        // the discarded scenes, as they will not return.
    }

    func applicationWillResignActive(_ application: UIApplication) {
        os_log(.info, log: log, "applicationWillResignActive")
        movingToBackground()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        os_log(.info, log: log, "applicationDidEnterBackground")
        movingToBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        os_log(.info, log: log, "applicationWillEnterForeground")
        CloudUploader.shared.startUploads()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        os_log(.info, log: log, "applicationDidBecomeActive")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        os_log(.info, log: log, "applicationWillTerminate")
        movingToBackground()
    }
}

extension AppDelegate {

    /// Controls uploading to iCloud. Note that although it is a settable value, the value returned will depend on
    /// whether the device can access iCloud. If it cannot, this will always return `false`
    public var uploadsEnabled: Bool {
        get { return CloudUploader.shared.enabled && FileManager.default.hasCloudDirectory }
        set { CloudUploader.shared.enabled = newValue }
    }

    private func movingToBackground() {
        NotificationCenter.default.post(name: stopRecordingRequest, object: nil)
        RecordingInfoManagedContext.shared.save()
        CloudUploader.shared.stopUploads()
    }
}

extension UIApplication {

    /// Short-hand for accessing the our delegate
    static var appDelegate: AppDelegate { return UIApplication.shared.delegate as! AppDelegate }
}
