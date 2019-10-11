// Copyright © 2019 Brad Howes. All rights reserved.

import CoreMotion

enum Datum {
    case acceleration(CMAccelerometerData)
    case deviceMotion(CMDeviceMotion)
    case gyro(CMGyroData)
    case magnetometer(CMMagnetometerData)
    case walkingMarker(Date)
    case turningMarker(Date)

    public var csv: String { row.map { "\($0)" }.joined(separator: ",") }

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

