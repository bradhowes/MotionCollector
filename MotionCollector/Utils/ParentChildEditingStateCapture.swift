// Copyright © 2019 Brad Howes. All rights reserved.

import Foundation

/**
 Simple protocol that tracks the `isEditing` values for two `UIViewController` instances, a
 parent and an internal child. The parent and the child must communicate their editing state
 their respective property. The implementor of the protocol can then reason on what to do given
 the two state values.
 */
protocol ParentChildEditingStateCapture: class {

    /// Editing state of the internal table view controller. When it becomes true but
    /// `parentEditing` is not, the user
    /// is swiping on a row, so we would disable the `Edit` button until the swipe actions go
    /// away.
    var childEditing: Bool { get set }

    /// Editing state of the parent controller. It becomes true when the `Edit` button is
    /// pressed.
    var parentEditing: Bool { get set }
}
