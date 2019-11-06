// CoreMotionController.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import os
import CoreMotion
import UIKit

/**
 Wrapper around the CMMotionManager to control how it is used.
 */
class CoreMotionController {
    lazy var log = Logging.logger("cmc")

    /// The source of all of the reports from iOS hardware.
    private let sensorManager = CMMotionManager()

    /// Holds the blocks being used to record different hardware reports
    private let operationQueue = OperationQueue()

    private let settings: Settings

    /// Custom _serialized_ queue. The work is done using threads from the global _utlility_ queue.
    let dataQueue = DispatchQueue(label: "dataQueue", qos: .utility, attributes: [], autoreleaseFrequency: .inherit,
                                  target: DispatchQueue.global(qos: .utility))

    var data = [String]()
    var state: Int = 0

    private var updateInterval: TimeInterval { 1.0 / TimeInterval(settings.samplesPerSecond) }

    init(_ settings: Settings) {
        self.settings = settings
        operationQueue.qualityOfService = .utility
        setUpdateIntervals()
    }

    func updateSettings() {
        pause()
        setUpdateIntervals()
        resume()
    }

    func setWalking() { dataQueue.async { Datum.label = .walk } }

    func setTurning() { dataQueue.async { Datum.label = .turn } }

    func start() {
        os_log(.info, log: log, "start")
        data.removeAll(keepingCapacity: true)
        setUpdateIntervals()

        resume()
    }

    func resume() {
        os_log(.info, log: log, "resume")
        if settings.useAccelerometer {
            os_log(.info, log: log, "using accelerometer")
            let proc = processGenerator(
                bad: { _ in self.sensorManager.stopAccelerometerUpdates() },
                good: { data in self.dataQueue.async { self.add(.acceleration(data)) } })
            sensorManager.startAccelerometerUpdates(to: operationQueue, withHandler: proc)
        }

        if settings.useDeviceMotion {
            os_log(.info, log: log, "using deviceMotion")
            let proc = processGenerator(
                bad: { _ in self.sensorManager.stopDeviceMotionUpdates() },
                good: { data in self.dataQueue.async { self.add(.deviceMotion(data)) } })
            sensorManager.startDeviceMotionUpdates(to: operationQueue, withHandler: proc)
        }

        if settings.useGyro {
            os_log(.info, log: log, "using gyro")
            let proc = processGenerator(
                bad: { _ in self.sensorManager.stopGyroUpdates() },
                good: { data in self.dataQueue.async { self.add(.gyro(data)) } })
            sensorManager.startGyroUpdates(to: operationQueue, withHandler: proc)
        }

        if settings.useMagnetometer {
            os_log(.info, log: log, "using magnetometer")
            let proc = processGenerator(
                bad: { _ in self.sensorManager.stopMagnetometerUpdates() },
                good: { data in self.dataQueue.async { self.add(.magnetometer(data)) } })
            sensorManager.startMagnetometerUpdates(to: operationQueue, withHandler: proc)
        }

        RecordingStateChangeNotification.post(value: true)
    }

    func stop(_ block: ([String])->Void) {
        os_log(.info, log: log, "stop")
        pause()
        block([Datum.header] + data)
    }

    func pause() {
        os_log(.info, log: log, "pause")
        if sensorManager.isAccelerometerActive { sensorManager.stopAccelerometerUpdates() }
        if sensorManager.isDeviceMotionActive { sensorManager.stopDeviceMotionUpdates() }
        if sensorManager.isGyroActive { sensorManager.stopGyroUpdates() }
        if sensorManager.isMagnetometerActive { sensorManager.stopMagnetometerUpdates() }
    }

    func update(_ block: @escaping (Int)->Void) {
        self.dataQueue.async { block(self.data.count) }
    }

    private func setUpdateIntervals() {
        let rate = self.updateInterval
        os_log(.info, log: log, "setUpdateIntervals - %f", rate)
        if sensorManager.isAccelerometerAvailable { sensorManager.accelerometerUpdateInterval = rate }
        if sensorManager.isDeviceMotionAvailable { sensorManager.deviceMotionUpdateInterval = rate }
        if sensorManager.isGyroAvailable { sensorManager.gyroUpdateInterval = rate }
        if sensorManager.isMagnetometerAvailable { sensorManager.magnetometerUpdateInterval = rate }
    }

    private func add(_ datum: Datum) {
        self.data.append(datum.csv)
    }

    private func processGenerator<DataType>(bad: @escaping (Error)->Void,
                                            good: @escaping (DataType)->Void) -> (DataType?, Error?)->Void {
        return {data, err in
            if let data = data {
                good(data)
            }
            else if let err = err {
                os_log(.error, log: self.log, "error: %s", err.localizedDescription)
                bad(err)
            }
        }
    }
}
