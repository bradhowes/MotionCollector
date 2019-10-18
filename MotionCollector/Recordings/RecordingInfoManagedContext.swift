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
    public typealias Stack = CoreDataStack<PersistentContainer>

    static let shared = RecordingInfoManagedContext()

    /// Loader for the managed context for RecordingInfo instances.
    private let stack = Stack(container: PersistentContainer(name: "RecordingInfo"))

    /// Obtain a new RecordingInfo managed object. NOTE: this must not be called until there is a valid
    /// NSManagedObjectContext available to create a managed object. Best approach is to use `registerLoadedNotifier`
    /// below and only allow calls to `newObject` after the notifier fires.
    public var newObject: RecordingInfo { context!.insertObject() }

    /// Obtain the known NSManagedObjectContext for RecordingInfo instances.
    public var context: NSManagedObjectContext? { return stack.managedObjectContext }

    public var availableNotification: Stack.AvailableNotification { return stack.availableNotification }

    private init() {}

    /**
     Attempt to save whatever changes may be pending in the managed context.
     */
    public func save() { try? context?.save() }
}
