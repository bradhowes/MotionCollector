// RecordingsManagedContext.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit
import CoreData

/// Notification that recording is to stop.
let stopRecordingRequest = Notification.Name(rawValue: "StopRecordingRequest")

/**
 Container that loads and retains a Core Data persistent container for RecordingInfo entities. There is only one
 instance of this class that is obtained via the `shared` attribute.
 */
public struct RecordingInfoManagedContext {

    static let shared = RecordingInfoManagedContext()

    /// Loader for the managed context for RecordingInfo instances.
    public let stack = CoreDataStack(container: PersistentContainer(name: "RecordingInfo"))

    /// Obtain a new RecordingInfo managed object. NOTE: this must not be called until there is a valid
    /// NSManagedObjectContext available to create a managed object. Best approach is to use `registerLoadedNotifier`
    /// below and only allow calls to `newObject` after the notifier fires.
    var newObject: RecordingInfo { context!.insertObject() }

    /// Obtain the known NSManagedObjectContext for RecordingInfo instances.
    public var context: NSManagedObjectContext? { return stack.managedObjectContext }

    private init() {}

    /**
     Attempt to save whatever changes may be pending in the managed context.
     */
    public func save() { try? context?.save() }

    /**
     Register a closure to call when the RecordingInfo managed context is available.

     - parameter block: closure to call when available
     - returns: NotificationObserver instance to hold onto while observing the state of the managed context
     */
    public func registerLoadedNotifier(_ block: @escaping (NSManagedObjectContext)->Void) -> NotificationObserver {
        return stack.register(block: block)
    }
}
