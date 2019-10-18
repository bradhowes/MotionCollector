// CoreDataStack.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import CoreData

/**
 Initializes a CoreData stack. The T template value is an NSPersistentContainer type that can properly
 locate the CoreData model definition file in the right bundle.
 */
public class CoreDataStack<T: NSPersistentContainer> {
    public typealias AvailableNotification = CachedValueTypedNotification<NSManagedObjectContext>

    public let availableNotification: AvailableNotification

    private let persistentContainer: T

    /// The context associated with all managed objects from the persistent container
    public var managedObjectContext: NSManagedObjectContext? { return availableNotification.cachedValue }

    /**
     Construct a new CoreData stack that will provide values from a given container

     - parameter container: the container to provide
     */
    public required init(container: T) {
        self.availableNotification = AvailableNotification(name: container.name + "ManagedObjectContext")
        self.persistentContainer = container
        self.create()
    }

    private func create() {
        persistentContainer.loadPersistentStores { [weak self] _, err in
            guard let wself = self else { return }
            guard err == nil else { fatalError("Failed to load store: \(err!)") }
            let vc = wself.persistentContainer.viewContext
            wself.availableNotification.post(value: vc)
        }
    }
}
