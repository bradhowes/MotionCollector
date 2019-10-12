// Copyright © 2019 Brad Howes. All rights reserved.

import Foundation
import os

/**
 Typed notification definition. Template argument defines the type of a value that will be transmitted in the
 notification userInfo["value"] slot.
 */
open class TypedNotification<A> {

    /// The name of the notification
    public let name: Notification.Name

    /**
     Construct a new notification definition.

     - parameter name: the unique name for the notification
     */
    public required init(name: String) {
        self.name = Notification.Name(name)
    }

    /**
     Post this notification to all observers of it

     - parameter value: the value to forward to the observers
     */
    open func post(value: A) {
        let userInfo = ["value": value]
        NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
    }

    /**
     Register an observer to receive this notification defintion.

     - parameter block: a closure to execute when this kind of notification arrives
     - returns: a NotificationObserver instance that records the registration.
     */
    open func registerOnAny(block: @escaping (A) -> Void) -> NotificationObserver {
        return NotificationObserver(notification: self, block: block)
    }

    open func registerOnMain(block: @escaping (A) -> Void) -> NotificationObserver {
        return NotificationObserver(notification: self) { arg in
            DispatchQueue.main.async { block(arg) }
        }
    }
}

/**
 Manager of a TypedNotification registration. When the instance is no longer being held, it will automatically
 unregister the internal observer from future notification events.
 */
public class NotificationObserver {

    private let name: Notification.Name
    private let observer: NSObjectProtocol

    /**
     Create a new observer for the given typed notification
     */
    public init<A>(notification: TypedNotification<A>, block aBlock: @escaping (A) -> Void) {
        name = notification.name
        observer = NotificationCenter.default.addObserver(forName: notification.name, object: nil, queue: nil) { note in
            guard let value = note.userInfo?["value"] as? A else { fatalError("Couldn't understand user info") }
            aBlock(value)
        }
    }

    public func forget() {
        NotificationCenter.default.removeObserver(observer)
    }

    /**
     Cleanup notification registration by removing our internal observer from notifications.
     */
    deinit {
        forget()
    }
}
