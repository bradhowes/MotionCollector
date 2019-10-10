// Copyright © 2019 Brad Howes. All rights reserved.

import CoreData

public extension NSManagedObjectContext {

    func insertObject<A: NSManagedObject>() -> A where A: Managed {
        guard let obj = NSEntityDescription.insertNewObject(forEntityName: A.entityName, into: self) as? A else {
            fatalError("Wrong object type")
        }
        return obj
    }

    @discardableResult func saveOrRollback() -> Bool {
        do {
            try save()
            return true
        }
        catch {
            rollback()
            return false
        }
    }

    func performChanges(block: @escaping () -> ()) {
        perform {
            block()
            _ = self.saveOrRollback()
        }
    }
}

public struct ContextDidSaveNotification<T: NSManagedObject> {
    fileprivate let notification: Notification

    public init(notification: Notification) {
        guard notification.name == .NSManagedObjectContextDidSave else { fatalError() }
        self.notification = notification
    }

    public var insertedObjects: AnyIterator<T> {
        return iterator(forKey: NSInsertedObjectsKey)
    }

    public var updatedObjects: AnyIterator<T> {
        return iterator(forKey: NSUpdatedObjectsKey)
    }
    public var deletedObjects: AnyIterator<T> {
        return iterator(forKey: NSDeletedObjectsKey)
    }

    public var managedObjectContext: NSManagedObjectContext {
        guard let context = notification.object as? NSManagedObjectContext else {
            fatalError("invalid notification object") }
        return context
    }

    fileprivate func iterator(forKey key: String) -> AnyIterator<T> {
        guard let collection = notification.userInfo?[key] as? NSSet else {
            return AnyIterator { nil }
        }

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

public extension NSManagedObjectContext {

    func addContextDidSaveNotificationObserver<T: NSManagedObject>(_ handler: @escaping (ContextDidSaveNotification<T>) -> ()) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: self,
                                                      queue: nil) { notification in
            let wrapped = ContextDidSaveNotification<T>(notification: notification)
            handler(wrapped)
        }
    }
}
