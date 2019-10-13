// CoreMotionController.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import os
import CoreMotion

private enum SettingName: String {
    case samplesPerSecond
    case useAccelerometer
    case useDeviceMotion
    case useGyro
    case useMagnetometer
}


fileprivate extension UserDefaults {
    func enabled(for name: SettingName) -> Bool {
        let exists = self.object(forKey: name.rawValue) != nil
        return exists ? self.bool(forKey: name.rawValue) : true
    }

    func integer(for name: SettingName) -> Int {
        return self.integer(forKey: name.rawValue)
    }
}

/**
 Wrapper around the CMMotionManager to control how it is used.
 */
class CoreMotionController: OptionsViewManager {
    lazy var log = Logging.logger("cmc")

    /// The source of all of the reports from iOS hardware.
    private let sensorManager = CMMotionManager()

    /// Holds the blocks being used to record different hardware reports
    private let operationQueue = OperationQueue()

    /// Custom _serialized_ queue. The work is done using threads from the global _utlility_ queue.
    let dataQueue = DispatchQueue(label: "dataQueue", qos: .utility, attributes: [], autoreleaseFrequency: .inherit,
                                  target: DispatchQueue.global(qos: .utility))

    /// The number of samples per second emitted by the CMMotionManager. This is per hardware device, so for four
    /// devices (maximum), the number of reports generated would be 4x this number.
    var samplesPerSecond: Int = 10 { didSet { setUpdateIntervals() } }

    var useAccelerometer: Bool { didSet { updateSetting(.useAccelerometer, with: useAccelerometer) } }
    var useDeviceMotion: Bool { didSet { updateSetting(.useDeviceMotion, with: useDeviceMotion) } }
    var useGyro: Bool { didSet { updateSetting(.useGyro, with: useGyro) } }
    var useMagnetometer: Bool { didSet { updateSetting(.useMagnetometer, with: useMagnetometer) } }

    var data = [String]()
    var state: Int = 0

    private var updateInterval: TimeInterval { 1.0 / TimeInterval(samplesPerSecond) }

    init() {
        operationQueue.qualityOfService = .utility
        let defaultSettings: [SettingName: Any] = [
            .samplesPerSecond: 10,
            .useAccelerometer: true,
            .useDeviceMotion: true,
            .useGyro: true,
            .useMagnetometer: true
        ]

        let defaults = UserDefaults.standard
        defaults.register(defaults: Dictionary<String,Any>(uniqueKeysWithValues: defaultSettings.map { ($0.0.rawValue, $0.1) }))

        samplesPerSecond = defaults.integer(for: .samplesPerSecond)
        useAccelerometer = sensorManager.isAccelerometerAvailable && defaults.enabled(for: .useAccelerometer)
        useDeviceMotion = sensorManager.isDeviceMotionAvailable && defaults.enabled(for: .useDeviceMotion)
        useGyro = sensorManager.isGyroAvailable && defaults.enabled(for: .useGyro)
        useMagnetometer = sensorManager.isMagnetometerAvailable && defaults.enabled(for: .useMagnetometer)
        setUpdateIntervals()
    }

    func setWalking() { dataQueue.async { self.add(.walkingMarker(Date())) } }

    func setTurning() { dataQueue.async { self.add(.turningMarker(Date())) } }

    func start() {
        os_log(.info, log: log, "start")
        data.removeAll(keepingCapacity: true)
        setUpdateIntervals()

        if useAccelerometer && sensorManager.isAccelerometerAvailable {
            os_log(.info, log: log, "using accelerometer")
            let proc = processGenerator(
                bad: { _ in self.sensorManager.stopAccelerometerUpdates() },
                good: { data in self.dataQueue.async { self.add(.acceleration(data)) } })
            sensorManager.startAccelerometerUpdates(to: operationQueue, withHandler: proc)
        }

        if useDeviceMotion && sensorManager.isDeviceMotionAvailable {
            os_log(.info, log: log, "using deviceMotion")
            let proc = processGenerator(
                bad: { _ in self.sensorManager.stopDeviceMotionUpdates() },
                good: { data in self.dataQueue.async { self.add(.deviceMotion(data)) } })
            sensorManager.startDeviceMotionUpdates(to: operationQueue, withHandler: proc)
        }

        if useGyro && sensorManager.isGyroAvailable {
            os_log(.info, log: log, "using gyro")
            let proc = processGenerator(
                bad: { _ in self.sensorManager.stopGyroUpdates() },
                good: { data in self.dataQueue.async { self.add(.gyro(data)) } })
            sensorManager.startGyroUpdates(to: operationQueue, withHandler: proc)
        }

        if useMagnetometer && sensorManager.isMagnetometerAvailable {
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
        if sensorManager.isAccelerometerActive { sensorManager.stopAccelerometerUpdates() }
        if sensorManager.isDeviceMotionActive { sensorManager.stopDeviceMotionUpdates() }
        if sensorManager.isGyroActive { sensorManager.stopGyroUpdates() }
        if sensorManager.isMagnetometerActive { sensorManager.stopMagnetometerUpdates() }
        block([Datum.header] + data)
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
        updateSetting(.samplesPerSecond, with: samplesPerSecond)
    }

    private func add(_ datum: Datum) {
        self.data.append(datum.csv)
    }

    private func updateSetting<T>(_ name: SettingName, with value: T) {
        UserDefaults.standard.set(value, forKey: name.rawValue)
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
