// Copyright © 2019 Brad Howes. All rights reserved.

import CoreData
import Foundation

public struct ContextDidSaveNotification<T: NSManagedObject> {
    private let notification: Notification

    /// Obtain an interator over the objects that have been inserted.
    public var insertedObjects: AnyIterator<T> { iterator(forKey: NSInsertedObjectsKey) }

    /// Obtain an interator over the objects that have been updated.
    public var updatedObjects: AnyIterator<T> { iterator(forKey: NSUpdatedObjectsKey) }

    /// Obtain an interator over the objects that have been deleted.
    public var deletedObjects: AnyIterator<T> { iterator(forKey: NSDeletedObjectsKey) }

    public init(notification: Notification) {
        guard notification.name == .NSManagedObjectContextDidSave else { fatalError("incorrect notification") }
        self.notification = notification
    }

    public var managedObjectContext: NSManagedObjectContext {
        guard let context = notification.object as? NSManagedObjectContext else {
            fatalError("invalid notification object")
        }
        return context
    }

    private func iterator(forKey key: String) -> AnyIterator<T> {
        guard let collection = notification.userInfo?[key] as? NSSet else { return AnyIterator { nil } }
        var innerIterator = collection.makeIterator()
        return AnyIterator { return innerIterator.next() as? T }
    }
}

extension ContextDidSaveNotification: CustomDebugStringConvertible {
    public var debugDescription: String {
        var components = [notification.name.rawValue]
        components.append(managedObjectContext.description)
        for (name, collection) in [("inserted", insertedObjects), ("updated", updatedObjects), ("deleted", deletedObjects)] {
            let all = collection.map { $0.objectID.description }.joined(separator: ", ")
            components.append("\(name): {\(all)}")
        }
        return components.joined(separator: " ")
    }
}

