// Copyright © 2019 Brad Howes. All rights reserved.

import CoreMotion

/**
 The activity labels that can appear in the CSV files
 */
public enum Label: String {
    case walk   // User is currently walking
    case turn   // User is currently turning

    /// Obtain the label as a Double
    public var tag: Character { return self.rawValue.uppercased().first! }
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

    /// Transform event record into a String of comma-separated values.
    var csv: String {
        switch self {
        case let .acceleration(data, label):
            return fmt("A", label, data.when, data.acceleration.x, data.acceleration.y, data.acceleration.z)
        case let .deviceMotion(data, label):
            return fmt("D", label, data.when, data.rotationRate.x, data.rotationRate.y, data.rotationRate.z,
                       data.userAcceleration.x, data.userAcceleration.y, data.userAcceleration.z,
                       data.attitude.pitch, data.attitude.roll, data.attitude.yaw)
        case let .gyro(data, label):
            return fmt("G", label, data.when, data.rotationRate.x, data.rotationRate.y, data.rotationRate.z)
        case let .magnetometer(data, label):
            return fmt("M", label, data.when, data.magneticField.x, data.magneticField.y, data.magneticField.z)
        }
    }
}

private extension Datum {
    func fmt(_ d: Double) -> String { "\(d)" }
    func fmt(_ c: Character) -> String { "\(c)" }
    func fmt(_ tag: Character, _ label: Label, _ ds: Double...) -> String {
        ([tag, label.tag].map(fmt) + ds.map(fmt)).joined(separator: ",")
    }
}

private extension CMLogItem {

    /// Obtain an absolute timestamp for an event
    var when: TimeInterval { Date(timeIntervalSinceReferenceDate: self.timestamp).timeIntervalSince1970 }
}
