// Copyright © 2019 Brad Howes. All rights reserved.

import os
import UIKit
import CoreData


/**
 Delegate protocol for a TableViewSource instance. Combines a NSFetchedResults object (`Object`) with a UITableViewCell
 instance (`Cell`).
 */
public protocol TableViewDataSourceDelegate: class {
    associatedtype Object: NSFetchRequestResult
    associatedtype Cell: UITableViewCell

    /**
     Create a representation of a managed object in the given cell

     - parameter cell: the view to render into
     - parameter object: the object to render
     */
    func configure(_ cell: Cell, for object: Object)
    func canDelete(_ index: IndexPath) -> Bool
    func delete(_ obj: Object, at: IndexPath)
}

/**
 A data source for a UITableView that relies on a NSFetchedResultsController for model values.
 */
public class TableViewDataSource<Delegate: TableViewDataSourceDelegate>: NSObject, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    public typealias Object = Delegate.Object
    public typealias Cell = Delegate.Cell

    private let tableView: UITableView
    private let cellIdentifier: String
    private let fetchedResultsController: NSFetchedResultsController<Object>
    private weak var delegate: Delegate! // Lifetime is always as long as that of the delegate.

    /// Obtain the managed object for the currently selected row
    public var selectedObject: Object? {
        guard let indexPath = tableView.indexPathForSelectedRow else { return nil }
        return object(at: indexPath)
    }

    /**
     Construct a new instance.

     - parameter tableView: the UITableView that will show the rendered model instances
     - parameter cellIdentifier: the identifier of the UITableViewCell to use for rendering
     - parameter fetchedResultsController: the source of model instances from Core Data
     - parameter delegate: the delegate for rendering and deletion handling
     */
    public required init(tableView: UITableView, cellIdentifier: String,
                         fetchedResultsController: NSFetchedResultsController<Object>, delegate: Delegate) {
        self.tableView = tableView
        self.cellIdentifier = cellIdentifier
        self.fetchedResultsController = fetchedResultsController
        self.delegate = delegate
        super.init()

        fetchedResultsController.delegate = self
        try! fetchedResultsController.performFetch()
        tableView.dataSource = self
        tableView.reloadData()
    }

    /// Obtain the number of model instances, or the number of rows in the UITableView.
    public var count: Int { return fetchedResultsController.fetchedObjects?.count ?? 0 }

    /**
     Obtain the model instance for a given UITableView row.

     - parameter indexPath: the row to fetch
     - returns: the found model instance
     */
    public func object(at indexPath: IndexPath) -> Object {
        return fetchedResultsController.object(at: indexPath)
    }

    /**
     Change an existing Core Data fetch request and execute it.

     - parameter configure: block to run to edit the request
     */
    public func reconfigureFetchRequest(_ configure: (NSFetchRequest<Object>) -> ()) {
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: fetchedResultsController.cacheName)
        configure(fetchedResultsController.fetchRequest)
        do { try fetchedResultsController.performFetch() } catch { fatalError("fetch request failed") }
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = fetchedResultsController.sections?[section] else { return 0 }
        return section.numberOfObjects
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let obj = object(at: indexPath)
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? Cell else {
            fatalError("unexpected cell type at \(indexPath)")
        }
        delegate.configure(cell, for: obj)
        return cell
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return self.delegate.canDelete(indexPath)
    }

    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                          forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let obj = object(at: indexPath)
            delegate.delete(obj, at: indexPath)
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate

    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any,
                           at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            guard let indexPath = newIndexPath else { fatalError("indexPath should not be nil") }
            tableView.insertRows(at: [indexPath], with: .fade)

        case .update:
            guard let indexPath = newIndexPath else { fatalError("indexPath should not be nil") }
            guard let cell = tableView.cellForRow(at: indexPath) as? Cell else { break }
            delegate.configure(cell, for: object(at: indexPath))

        case .move:
            guard let indexPath = indexPath else { fatalError("indexPath should not be nil") }
            guard let newIndexPath = newIndexPath else { fatalError("newIndexPath should not be nil") }
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.insertRows(at: [newIndexPath], with: .fade)

        case .delete:
            guard let indexPath = indexPath else { fatalError("indexPath should not be nil") }
            tableView.deleteRows(at: [indexPath], with: .fade)

        @unknown default:
            fatalError("unexpected NSFetchedResultsChangeType value - \(type) ")
        }
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
