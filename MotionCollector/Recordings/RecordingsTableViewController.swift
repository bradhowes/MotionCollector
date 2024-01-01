// Copyright © 2019, 2024 Brad Howes. All rights reserved.

import os
import UIKit
import CoreData

/**
 UITableViewController that shows entries for all known RecordingInfo instances. Supports left and right swiping for
 actions per row, and editing of cells to delete past recordings.
 */
final class RecordingsTableViewController: UITableViewController {
  private lazy var log = Logging.logger("rtvc")

  /// The manager of the data for the table view.
  private var dataSource: TableViewDataSource<RecordingsTableViewController>!

  /// Obtain the number of rows in the table.
  public var count: Int { return dataSource.count }

  /**
   View is going to appear. Set up the data source to show the recordings in the table view as well as track their
   changes.

   - parameter animated: if true the disappearance will be animated
   */
  override func viewWillAppear(_ animated: Bool) {
    os_log(.info, log: log, "viewWillAppear")
    setupTableView()
    super.viewWillAppear(animated)
  }

  /**
   View is going to disappear. Disconnect the data source so that it won't be tracking changes to recordings.

   - parameter animated: if true the disappearance will be animated
   */
  override func viewWillDisappear(_ animated: Bool) {
    os_log(.info, log: log, "viewWilDisappear")
    super.viewWillDisappear(animated)
    dataSource = nil
  }
}

// MARK: - TableViewDataSourceDelegate

extension RecordingsTableViewController: TableViewDataSourceDelegate {

  /**
   Configure a cell to show the values from a given RecordingInfo

   - parameter cell: the cell to render into
   - parameter object: the RecordingInfo instance to render
   */
  func configure(_ cell: RecordingInfoTableViewCell, for object: RecordingInfo) {
    RecordingInfoCellConfigurator.configure(cell: cell, with: object)
    updateEditState()
  }

  /**
   Determine if the given row can be deleted.

   - parameter indexPath: index of the row to check
   - returns: true if the row can be deleted
   */
  func canDelete(_ indexPath: IndexPath) -> Bool {
    return indexPath.row > 0 || !dataSource.object(at: indexPath).isRecording
  }

  /**
   Delete a row.

   - parameter obj: the RecordingInfo instance to delete
   - parameter at: the row representing the recording
   */
  func delete(_ obj: RecordingInfo, at indexPath: IndexPath) {
    os_log(.info, log: log, "delete - %d", indexPath.row)
    obj.delete()
  }

  /**
   Notification from the data source that the table view changed.
   */
  func updated() {
    updateEditState()
  }

  private func updateEditState() {
    let count = dataSource.count
    let canEdit = (count == 1 && canDelete(IndexPath(row: 0, section: 0))) || count > 1
    os_log(.info, log: log, "updateEditState - %d %d %d", count, canEdit, tableView.isEditing)
    if !canEdit {
      DispatchQueue.main.async {
        self.tableView.setEditing(false, animated: true)
        self.editButtonItem.isEnabled = canEdit
      }
    }
    else {
      editButtonItem.isEnabled = true
    }
  }
}

// MARK: - Swipe Actions of UITableViewDelegate

extension RecordingsTableViewController {

  /**
   Query about the kind of editing that can be done on a given row

   - parameter tableView: the UITableView being queried
   - parameter indexPath: the row being queried
   - returns: the editing that can take place on the row
   */
  override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath)
    -> UITableViewCell.EditingStyle {
    let recordingInfo = dataSource.object(at: indexPath)
    return !recordingInfo.isRecording && tableView.isEditing ? .delete : .none
  }

  /**
   Query about the swipe operations available at the beginning of the cell (eg swipe right for left-to-right text
   flows.

   - parameter tableView: the UITableView being queried
   - parameter indexPath: the row being queried
   - returns: the swipe actions for the row
   */
  override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
    let recordingInfo = dataSource.object(at: indexPath)
    guard !recordingInfo.isRecording else { return nil }
    return RecordingInfoCellConfigurator.makeLeadingSwipeActions(with: recordingInfo,
                                                                 cell: tableView.cellForRow(at: indexPath))
  }

  /**
   Query about the swipe operations available at the end of the cell (eg swipe left for left-to-right text
   flows.

   - parameter tableView: the UITableView being queried
   - parameter indexPath: the row being queried
   - returns: the swipe actions for the row
   */
  override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
    let recordingInfo = dataSource.object(at: indexPath)
    guard !recordingInfo.isRecording else { return nil }
    return RecordingInfoCellConfigurator.makeTrailingSwipeActions(controller: self) {
      recordingInfo.delete()
    }
  }
}

// MARK: - Private

private extension RecordingsTableViewController {

  func setupTableView() {
    editButtonItem.isEnabled = false
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 100

    guard let managedContext = RecordingInfoManagedContext.shared.context else {
      fatalError("nil recordingInfoManagedContext")
    }

    let request = RecordingInfo.sortedFetchRequest
    request.fetchBatchSize = 40
    request.returnsObjectsAsFaults = false
    let frc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: managedContext,
                                         sectionNameKeyPath: nil, cacheName: nil)
    dataSource = TableViewDataSource(tableView: tableView, cellIdentifier: "RecordingInfo",
                                     fetchedResultsController: frc, delegate: self)

    // TODO: there are update and state management issue with this button and the delete swipe.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem
  }
}
