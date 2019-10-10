// CoreDataStack.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import CoreData

/**
 Initializes a CoreData stack. The T template value is an NSPersistentContainer type that can properly
 locate the CoreData model definition file in the right bundle.
 */
public class CoreDataStack<T: NSPersistentContainer> {

    private let notification: CachedValueTypedNotification<NSManagedObjectContext>
    private let persistentContainer: T

    /// The context associated with all managed objects from the persistent container
    public var managedObjectContext: NSManagedObjectContext? { return notification.cachedValue }

    /**
     Construct a new CoreData stack that will provide values from a given container

     - parameter container: the container to provide
     */
    public required init(container: T) {
        self.notification = CachedValueTypedNotification<NSManagedObjectContext>(
            name: container.name + "ManagedObjectContext")
        self.persistentContainer = container
        self.create()
    }

    private func create() {
        persistentContainer.loadPersistentStores { [weak self] _, err in
            guard let wself = self else { return }
            guard err == nil else { fatalError("Failed to load store: \(err!)") }
            let vc = wself.persistentContainer.viewContext

            DispatchQueue.main.async {
                wself.notification.post(value: vc)
            }
        }
    }

    /**
     Register a closure to invoke when the CoreData stack is initialized for the persistent container.

     - parameter block: the closure to invoke
     - returns: a reference for the registration that will remove the registration when it goes out of scope.
     */
    public func register(block: @escaping (NSManagedObjectContext) -> Void) -> NotificationObserver {
        return self.notification.registerOnAny(block: block)
    }
}
