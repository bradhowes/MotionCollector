// CoreMotionController.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import CoreMotion

class CoreMotionController {
    let sensorManager = CMMotionManager()
    let operationQueue = OperationQueue()

    // Create a custom _serialized_ queue, but have the work done using threads from the global _utlility_ queue.
    let dataQueue = DispatchQueue(label: "dataQueue", qos: .utility, attributes: [], autoreleaseFrequency: .inherit,
                                  target: DispatchQueue.global(qos: .utility))

    var data = [String]()
    var state: Int = 0

    init() {
        operationQueue.qualityOfService = .utility
        if sensorManager.isAccelerometerAvailable { sensorManager.accelerometerUpdateInterval = 0.1 }
        if sensorManager.isDeviceMotionAvailable { sensorManager.deviceMotionUpdateInterval = 0.1 }
        if sensorManager.isGyroAvailable { sensorManager.gyroUpdateInterval = 0.1 }
        if sensorManager.isMagnetometerAvailable { sensorManager.magnetometerUpdateInterval = 0.1 }
    }

    func setWalking() { dataQueue.async { self.add(.walkingMarker(Date())) } }

    func setTurning() { dataQueue.async { self.add(.turningMarker(Date())) } }

    func start() {
        data.removeAll(keepingCapacity: true)
        data.append(Datum.header)

        if sensorManager.isAccelerometerAvailable {
            let proc = processGenerator(
                bad: { _ in self.sensorManager.stopAccelerometerUpdates() },
                good: { data in self.dataQueue.async { self.add(.acceleration(data)) } })
            sensorManager.startAccelerometerUpdates(to: operationQueue, withHandler: proc)
        }

        if sensorManager.isDeviceMotionAvailable {
            let proc = processGenerator(
                bad: { _ in self.sensorManager.stopDeviceMotionUpdates() },
                good: { data in self.dataQueue.async { self.add(.deviceMotion(data)) } })
            sensorManager.startDeviceMotionUpdates(to: operationQueue, withHandler: proc)
        }

        if sensorManager.isGyroAvailable {
            let proc = processGenerator(
                bad: { _ in self.sensorManager.stopGyroUpdates() },
                good: { data in self.dataQueue.async { self.add(.gyro(data)) } })
            sensorManager.startGyroUpdates(to: operationQueue, withHandler: proc)
        }

        if sensorManager.isMagnetometerAvailable {
            let proc = processGenerator(
                bad: { _ in self.sensorManager.stopMagnetometerUpdates() },
                good: { data in self.dataQueue.async { self.add(.magnetometer(data)) } })
            sensorManager.startMagnetometerUpdates(to: operationQueue, withHandler: proc)
        }

        RecordingStateChangeNotification.post(value: true)
    }

    func stop(_ block: ([String])->Void) {
        if sensorManager.isAccelerometerAvailable { sensorManager.stopAccelerometerUpdates() }
        if sensorManager.isDeviceMotionAvailable { sensorManager.stopDeviceMotionUpdates() }
        if sensorManager.isGyroAvailable { sensorManager.stopGyroUpdates() }
        if sensorManager.isMagnetometerAvailable { sensorManager.stopMagnetometerUpdates() }
        block(data)
    }

    func update(_ block: @escaping (Int)->Void) {
        self.dataQueue.async { block(self.data.count) }
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
                print("*** \(err)")
                bad(err)
            }
        }
    }
}
