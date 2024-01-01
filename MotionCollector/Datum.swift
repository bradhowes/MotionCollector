// Copyright © 2019, 2024 Brad Howes. All rights reserved.

import CoreMotion

/**
 The activity labels that can appear in the CSV files
 */
public enum Label: String {
  case walk = "W"
  case turn = "T"
}

/**
 Definition of the different reports that will be emitted by the application to a CSV recording file.
 */
public enum Datum {
  case acceleration(CMAccelerometerData, Label)
  case deviceMotion(CMDeviceMotion, Label)
  case gyro(CMGyroData, Label)
  case magnetometer(CMMagnetometerData, Label)
}

// MARK: - CSV Methods
public extension Datum {

  /// Obtain a header for the CSV file
  static let header = "Source, Label, When, X, Y, Z, UA_X, UA_Y, UA_Z, Pitch, Roll, Yaw"

  /// Get the time interval from the payload
  var when: TimeInterval {
    switch self {
    case .acceleration(let data, _): return data.timestamp
    case .deviceMotion(let data, _): return data.timestamp
    case .gyro(let data, _): return data.timestamp
    case .magnetometer(let data, _): return data.timestamp
    }
  }

  /**
   Transform a payload into a string with comma-separated values.

   - parameter start: the base time value to use when calculating event delta time
   - returns CSV value
   */
  func csv(_ start: TimeInterval) -> String {
    switch self {
    case let .acceleration(data, label):
      return fmt("A", label, data.delta(start), data.acceleration.x, data.acceleration.y, data.acceleration.z)
    case let .deviceMotion(data, label):
      return fmt("D", label, data.delta(start), data.rotationRate.x, data.rotationRate.y, data.rotationRate.z,
                 data.userAcceleration.x, data.userAcceleration.y, data.userAcceleration.z,
                 data.attitude.pitch, data.attitude.roll, data.attitude.yaw)
    case let .gyro(data, label):
      return fmt("G", label, data.delta(start), data.rotationRate.x, data.rotationRate.y, data.rotationRate.z)
    case let .magnetometer(data, label):
      return fmt("M", label, data.delta(start), data.magneticField.x, data.magneticField.y, data.magneticField.z)
    }
  }
}

public extension Array where Element == Datum {

  /// Convenience property that transforms array of Datum into a String containing CSV rows separated by linefeeds
  var text: String {
    ([Datum.header] + self.map({ $0.csv(self.first?.when ?? 0.0) })).joined(separator: "\n") + "\n"
  }
}

private extension Datum {
  func fmt(_ value: Double) -> String { "\(value)" }
  func fmt(_ tag: String, _ label: Label, _ doubles: Double...) -> String {
    ([tag, label.rawValue] + doubles.map(fmt)).joined(separator: ",")
  }
}

private extension CMLogItem {

  /// Obtain an delta from starting timestamp. This is mostly aesthetic since the timestamp for any CMLogItem is just
  /// the time from the last boot of the device. It just makes the values smaller.
  func delta( _ start: TimeInterval) -> TimeInterval { self.timestamp - start }
}
