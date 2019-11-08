// CoreMotionController.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import os
import CoreMotion
import UIKit

/**
 Wrapper around the CMMotionManager to control how it is used.
 */
final class CoreMotionController {
    lazy var log = Logging.logger("cmc")

    private let settings: Settings
    private let sensorManager: CMMotionManager

    /// Holds the blocks being used to record different hardware reports
    private let operationQueue = OperationQueue()

    /// Custom _serialized_ queue. The work is done using threads from the global _utlility_ queue.
    private let dataQueue = DispatchQueue(label: "dataQueue", qos: .utility, attributes: [],
                                          autoreleaseFrequency: .inherit, target: DispatchQueue.global(qos: .utility))

    private var label: Label = .walk
    private var data = [Datum]()
    private var updateInterval: TimeInterval { 1.0 / TimeInterval(settings.samplesPerSecond) }
    private var running: Bool = false

    /**
     Construct a simple controller for a CMMotionManager

     - parameter settings: various settings that determine what events to collect from the CMMotionManager
     - parameter sensorManager: the CMMotionManager instance to work with
     */
    public init(_ settings: Settings, sensorManager: CMMotionManager) {
        self.settings = settings
        self.sensorManager = sensorManager
        operationQueue.qualityOfService = .utility
        setUpdateIntervals()
    }

    /**
     Update current collection behavior based on setting values.
     */
    public func updateCollector() {
        if running {
            pause()
            setUpdateIntervals()
            resume()
        }
    }

    /**
     Set the current `label` for the collection to `walk`
     */
    public func setWalking() { dataQueue.async { self.label = .walk } }

    /**
     Set the current `label` for the collection to `turn`
     */
    public func setTurning() { dataQueue.async { self.label = .turn } }

    /**
     Start collecting sensor data.
     */
    public func start() {
        os_log(.info, log: log, "start")
        precondition(!running)
        data.removeAll(keepingCapacity: true)
        setUpdateIntervals()
        resume()
        running = true
    }

    /**
     Stop collecting sensor data.

     - parameter block: closure which accepts an array of CSV rows built from the sensor data.
     */
    public func stop(_ block: ([String])->Void) {
        os_log(.info, log: log, "stop")
        precondition(running)
        pause()
        running = false
        block([Datum.header] + data.map { $0.csv })
    }

    /**
     Provide an update of the number of rows collected so far

     - parameter block: closure which accepts the number of rows
     */
    public func update(_ block: @escaping (Int)->Void) {
        precondition(running)
        self.dataQueue.async { block(self.data.count) }
    }
}

// MARK: - Private

private extension CoreMotionController {

    func resume() {
        os_log(.info, log: log, "resume")
        if settings.useAccelerometer {
            os_log(.info, log: log, "using accelerometer")
            let proc = dataProcGen(sensorManager.stopAccelerometerUpdates, Datum.acceleration)
            sensorManager.startAccelerometerUpdates(to: operationQueue, withHandler: proc)
        }

        if settings.useDeviceMotion {
            os_log(.info, log: log, "using deviceMotion")
            let proc = dataProcGen(sensorManager.stopDeviceMotionUpdates, Datum.deviceMotion)
            sensorManager.startDeviceMotionUpdates(to: operationQueue, withHandler: proc)
        }

        if settings.useGyro {
            os_log(.info, log: log, "using gyro")
            let proc = dataProcGen(sensorManager.stopGyroUpdates, Datum.gyro)
            sensorManager.startGyroUpdates(to: operationQueue, withHandler: proc)
        }

        if settings.useMagnetometer {
            os_log(.info, log: log, "using magnetometer")
            let proc = dataProcGen(sensorManager.stopMagnetometerUpdates, Datum.magnetometer)
            sensorManager.startMagnetometerUpdates(to: operationQueue, withHandler: proc)
        }

        RecordingStateChangeNotification.post(value: true)
    }

    func pause() {
        os_log(.info, log: log, "pause")
        if sensorManager.isAccelerometerActive { sensorManager.stopAccelerometerUpdates() }
        if sensorManager.isDeviceMotionActive { sensorManager.stopDeviceMotionUpdates() }
        if sensorManager.isGyroActive { sensorManager.stopGyroUpdates() }
        if sensorManager.isMagnetometerActive { sensorManager.stopMagnetometerUpdates() }
    }

    func setUpdateIntervals() {
        let rate = self.updateInterval
        os_log(.info, log: log, "setUpdateIntervals - %f", rate)
        if sensorManager.isAccelerometerAvailable { sensorManager.accelerometerUpdateInterval = rate }
        if sensorManager.isDeviceMotionAvailable { sensorManager.deviceMotionUpdateInterval = rate }
        if sensorManager.isGyroAvailable { sensorManager.gyroUpdateInterval = rate }
        if sensorManager.isMagnetometerAvailable { sensorManager.magnetometerUpdateInterval = rate }
    }

    func dataProcGen<DataType>(_ stopper: @escaping () -> Void, _ wrapper: @escaping (DataType, Label) -> Datum)
        -> (DataType?, Error?) -> Void {
        return {data, err in
            if let data = data {
                self.dataQueue.async { self.data.append(wrapper(data, self.label)) }
            }
            if let err = err {
                os_log(.error, log: self.log, "error: %s", err.localizedDescription)
                stopper()
            }
        }
    }
}
