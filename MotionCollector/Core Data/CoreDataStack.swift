// CoreDataStack.swift
// Copyright © 2019, 2024 Brad Howes. All rights reserved.

import CoreData

/**
 Initializes a CoreData stack. The T template value is an NSPersistentContainer type that can properly
 locate the CoreData model definition file in the right bundle.
 */
public final class CoreDataStack<T: NSPersistentContainer> {
  public typealias AvailableNotification = CachedValueTypedNotification<NSManagedObjectContext>

  /// Notification that will be emitted when the persistent container is available to use.
  public let availableNotification: AvailableNotification

  /// The context associated with all managed objects from the persistent container
  public var managedObjectContext: NSManagedObjectContext? { return availableNotification.cachedValue }

  private let persistentContainer: T

  /**
   Construct a new Core Data stack that will provide values from a given persistent container

   - parameter container: the container to provide
   */
  public required init(container: T) {
    availableNotification = AvailableNotification(name: container.name + "ManagedObjectContext")
    persistentContainer = container
    create()
  }

  private func create() {
    persistentContainer.loadPersistentStores { [weak self] _, _ in
      guard let self = self else { return }
      let viewContext = self.persistentContainer.viewContext
      self.availableNotification.post(value: viewContext)
    }
  }
}
