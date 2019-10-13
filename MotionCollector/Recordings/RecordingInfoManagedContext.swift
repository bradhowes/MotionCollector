// RecordingsManagedContext.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit
import CoreData

/// Notification that recording is to stop.
let stopRecordingRequest = Notification.Name(rawValue: "StopRecordingRequest")

public struct RecordingInfoManagedContext {

    /// Loader for the managed context for RecordingInfo instances
    public var recordingInfoManagedContextLoader = CoreDataStack(container: PersistentContainer(name: "RecordingInfo"))

    /// Obtain the known NSManagedObjectContext for RecordingInfo instances.
    public var context: NSManagedObjectContext? {
        return recordingInfoManagedContextLoader.managedObjectContext
    }

    static var singleton = RecordingInfoManagedContext()

    static func save() {
        try? singleton.context?.save()
    }

    static func registerLoadedNotifier(_ block: @escaping (NSManagedObjectContext)->Void) -> NotificationObserver {
        return singleton.recordingInfoManagedContextLoader.register(block: block)
    }

    static func insertObject() -> RecordingInfo {
        return singleton.context!.insertObject()
    }
}
