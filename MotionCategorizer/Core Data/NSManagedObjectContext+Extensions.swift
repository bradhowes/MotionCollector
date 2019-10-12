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

public extension NSManagedObjectContext {

    func addContextDidSaveNotificationObserver<T: NSManagedObject>(_ handler: @escaping (ContextDidSaveNotification<T>) -> ()) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: self,
                                                      queue: nil) { notification in
            let wrapped = ContextDidSaveNotification<T>(notification: notification)
            handler(wrapped)
        }
    }
}
