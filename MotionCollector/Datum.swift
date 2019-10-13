// Copyright © 2019 Brad Howes. All rights reserved.

import CoreMotion

/**
 Definition of the different reports that will be emitted by the application to a CSV recording file.
 */
enum Datum {
    case acceleration(CMAccelerometerData)
    case deviceMotion(CMDeviceMotion)
    case gyro(CMGyroData)
    case magnetometer(CMMagnetometerData)
    case walkingMarker(Date)
    case turningMarker(Date)

    /// Obtain a string of comma-separated values
    public var csv: String { row.map { "\($0)" }.joined(separator: ",") }

    /// Obtain a header for the CSV file
    static let header = "Type, When, X, Y, Z, UA_X, UA_Y, UA_Z, Pitch, Roll, Yaw"

    /// Obtain an array of numbers for an event. The first is a numerical indication of the event type, followed by
    /// the time of the event in 
    public var row: [Double] {
        switch self {
        case .acceleration(let data):
            return [0, data.when, data.acceleration.x, data.acceleration.y, data.acceleration.z]
        case .deviceMotion(let data):
            return [1, data.when, data.rotationRate.x, data.rotationRate.y, data.rotationRate.z,
                    data.userAcceleration.x, data.userAcceleration.y, data.userAcceleration.z,
                    data.attitude.pitch, data.attitude.roll, data.attitude.yaw
            ]
        case .gyro(let data):
            return [2, data.when, data.rotationRate.x, data.rotationRate.y, data.rotationRate.z]
        case .magnetometer(let data):
            return [3, data.when, data.magneticField.x, data.magneticField.y, data.magneticField.z]
        case .walkingMarker(let when):
            return [4, when.timeIntervalSince1970]
        case .turningMarker(let when):
            return [5, when.timeIntervalSince1970]
        }
    }
}

extension CMLogItem {

    /// Obtain an absolute timestamp for an event
    public var when: TimeInterval { Date(timeIntervalSinceReferenceDate: self.timestamp).timeIntervalSince1970 }
}
