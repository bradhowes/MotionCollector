// Copyright © 2019, 2024 Brad Howes. All rights reserved.

import UIKit

/**
 Protocol definiton for objects that know about segues between UIView controllers. The protocol basically defines
 a type-safe way to translate from a UIStoryboardSeque.identifier value into a type-specific value (probably an enum)

 This idea came from the obj.io Core Data book (which itself came from a WWDC presentation I think)
 */
public protocol SegueHandler {
  associatedtype SegueIdentifier: RawRepresentable
}

public extension SegueHandler where Self: UIViewController, SegueIdentifier.RawValue == String {

  /**
   Obtain a segue identifier for a segue

   - parameter segue: the segue to look for
   - returns: the identifier for the segue
   */
  func segueIdentifier(for segue: UIStoryboardSegue) -> SegueIdentifier {

    /**
     Attempt to obtain a SegueIdentifier object for the given raw identifier.
     */
    guard let identifier = segue.identifier, let segueIdentifier = SegueIdentifier(rawValue: identifier) else {
      fatalError("unknown segue '\(segue.identifier!)'")
    }
    return segueIdentifier
  }

  /**
   Peform a known segue transition between two view controllers

   - parameter segueIdentifier: the identifier of the segue to perform
   */
  func performSegue(withIdentifier segueIdentifier: SegueIdentifier) {
    performSegue(withIdentifier: segueIdentifier.rawValue, sender: nil)
  }
}
