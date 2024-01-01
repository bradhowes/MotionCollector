// Copyright © 2019, 2024 Brad Howes. All rights reserved.

import Foundation

public struct RecordingNameGenerator {

  let date = Date()
  lazy var fileType: String = "csv"
  lazy var displayName = Formatters.displayNameFormatter.string(from: date)
  lazy var fileName: String = Formatters.fileNameFormatter.string(from: date) + "." + fileType

  static let recordingsDir: URL = {
    let fileManager = FileManager.default
    let docDir = fileManager.localDocumentsDirectory
    try? fileManager.createDirectory(at: docDir, withIntermediateDirectories: true, attributes: nil)
    return docDir
  }()

  static func recordingUrl(fileName: String) -> URL { recordingsDir.appendingPathComponent(fileName) }
}
