// Copyright © 2019 Brad Howes. All rights reserved.

import os
import UIKit
import CoreData

/**
 UITableViewController that shows entries for all known RecordingInfo instances. Supports left and right swiping for
 actions per row, and editing of cells to delete past recordings.
 */
final class RecordingsTableViewController: UITableViewController, SegueHandler {
    private lazy var log = Logging.logger("rtvc")

    /**
     Enumeration of the segues that can come from this controller.
     */
    enum SegueIdentifier: String {

        /**
         The embedded segue for the embedded UITableViewController
         */
        case embedRecordingsTableView = "embedRecordingsTableView"
    }

    private var dataSource: TableViewDataSource<RecordingsTableViewController>!

     /// Obtain the number of rows in the table.
    public var count: Int { return dataSource.count }

    override func viewDidLoad() {
        os_log(.info, log: log, "viewDidLoad")
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        os_log(.info, log: log, "viewWillAppear")
        setupTableView()
        super.viewWillAppear(animated)
    }

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

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        let recordingInfo = dataSource.object(at: indexPath)
        return !recordingInfo.isRecording && tableView.isEditing ? .delete : .none
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let recordingInfo = dataSource.object(at: indexPath)
        guard !recordingInfo.isRecording else { return nil }
        return RecordingInfoCellConfigurator.makeLeadingSwipeActions(with: recordingInfo,
                                                                     cell: tableView.cellForRow(at: indexPath))
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let recordingInfo = dataSource.object(at: indexPath)
        guard !recordingInfo.isRecording else { return nil }
        return RecordingInfoCellConfigurator.makeTrailingSwipeActions(vc: self) {
            recordingInfo.delete()
        }
    }
}

// MARK: - Private

extension RecordingsTableViewController {

    private func setupTableView() {
        editButtonItem.isEnabled = false

        guard let managedContext = UIApplication.appDelegate.recordingInfoManagedContext else { fatalError("nil recordingInfoManagedContext") }
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100

        let request = RecordingInfo.sortedFetchRequest
        request.fetchBatchSize = 40
        request.returnsObjectsAsFaults = false
        let frc = NSFetchedResultsController(fetchRequest: request,managedObjectContext: managedContext,
                                             sectionNameKeyPath: nil, cacheName: nil)
        dataSource = TableViewDataSource(tableView: tableView, cellIdentifier: "RecordingInfo",
                                         fetchedResultsController: frc, delegate: self)

        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
}
