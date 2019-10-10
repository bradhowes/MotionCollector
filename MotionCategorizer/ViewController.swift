//
//  ViewController.swift
//  MotionCategorizer
//
//  Created by Brad Howes on 10/8/19.
//  Copyright © 2019 Brad Howes. All rights reserved.
//

import UIKit
import CoreMotion

public let RecordingStateChangeNotification = TypedNotification<Bool>(name: "RecordingStateChange")

extension CMLogItem {
    public var when: TimeInterval { Date(timeIntervalSinceReferenceDate: self.timestamp).timeIntervalSince1970 }
}

class ViewController: UIViewController {
    @IBOutlet weak var elapsed: UILabel!
    @IBOutlet weak var startStop: UIButton!
    @IBOutlet weak var walking: UIButton!
    @IBOutlet weak var turning: UIButton!
    @IBOutlet weak var status: UILabel!

    let elapsedFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    var startTime: Date?
    var timer: Timer?

    let sensorManager = CMMotionManager()

    // Create a custom _serialized_ queue, but have the work done using threads from the global _utlility_ queue.
    let dataQueue = DispatchQueue(label: "dataQueue", qos: .utility, attributes: [], autoreleaseFrequency: .inherit,
                                  target: DispatchQueue.global(qos: .utility))

    let operationQueue = OperationQueue()

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

    var accelerometerData = [CMAccelerometerData]()
    var deviceMotionData = [CMDeviceMotion]()
    var gyroData = [CMGyroData]()
    var magnetometerData = [CMMagnetometerData]()

    var data = [String]()

    var recording: RecordingInfo?

    private func add(_ datum: Datum) {
        self.data.append(datum.csv)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setElapsed(0)

        operationQueue.qualityOfService = .utility

        if sensorManager.isAccelerometerAvailable {
            sensorManager.accelerometerUpdateInterval = 0.1
        }

        if sensorManager.isDeviceMotionAvailable {
            sensorManager.deviceMotionUpdateInterval = 0.1
        }

        if sensorManager.isGyroAvailable {
            sensorManager.gyroUpdateInterval = 0.1
        }

        if sensorManager.isMagnetometerAvailable {
            sensorManager.magnetometerUpdateInterval = 0.1
        }

        status.text = ""

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(beginWalking(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1

        NotificationCenter.default.addObserver(forName: stopRecordingRequest, object: nil, queue: nil) { _ in
            self.stop()
        }
    }

    @IBAction func startStop(_ sender: Any) {
        if self.timer != nil {
            stop()
        }
        else {
            start()
        }
    }

    @IBAction func beginWalking(_ sender: Any) {
        dataQueue.async { self.add(.walkingMarker(Date())) }
    }

    @IBAction func beginTurning(_ sender: Any) {
        dataQueue.async { self.add(.turningMarker(Date())) }
    }

    private func setElapsed(_ duration: TimeInterval) {
        self.elapsed.text = self.elapsedFormatter.string(from: duration)
    }

    private func start() {
        self.setElapsed(0)

        recording = RecordingInfo.insert()

        startTime = Date()
        startStop.setTitle("Stop", for: .normal)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let duration = Date().timeIntervalSince(self.startTime!)
            self.setElapsed(duration)
            self.dataQueue.async {
                let count = self.data.count
                DispatchQueue.main.async {
                    self.status.text = "\(count) records"
                    self.recording?.update(count: count)
                }
            }
        }

        data.removeAll(keepingCapacity: true)
        status.text = ""

        if sensorManager.isAccelerometerAvailable {
            print("-- starting accelerometer")
            accelerometerData = []
            sensorManager.startAccelerometerUpdates(to: operationQueue) { data, err in
                if let data = data {
                    self.dataQueue.async { self.add(.acceleration(data)) }
                }
                else if let err = err {
                    self.sensorManager.stopAccelerometerUpdates()
                    print("*** error: accelerometer \(err)")
                }
            }
        }

        if sensorManager.isDeviceMotionAvailable {
            print("-- starting deviceMotion")
            deviceMotionData = []
            sensorManager.startDeviceMotionUpdates(to: operationQueue) { data, err in
                if let data = data {
                    self.dataQueue.async { self.add(.deviceMotion(data)) }
                }
                else if let err = err {
                    self.sensorManager.stopDeviceMotionUpdates()
                    print("*** error: deviceMotion \(err)")
                }
            }
        }

        if sensorManager.isGyroAvailable {
            print("-- starting gyro")
            gyroData = []
            sensorManager.startGyroUpdates(to: operationQueue) { data, err in
                if let data = data {
                    self.dataQueue.async { self.add(.gyro(data)) }
                }
                else if let err = err {
                    self.sensorManager.stopGyroUpdates()
                    print("*** error: gyro \(err)")
                }
            }
        }

        if sensorManager.isMagnetometerAvailable {
            print("-- starting magnetometer")
            magnetometerData = []
            sensorManager.startMagnetometerUpdates(to: operationQueue) { data, err in
                if let data = data {
                    self.dataQueue.async { self.add(.magnetometer(data)) }
                }
                else if let err = err {
                    self.sensorManager.stopMagnetometerUpdates()
                    print("*** error: magnetometer \(err)")
                }
            }
        }

        RecordingStateChangeNotification.post(value: true)
    }

    private func stop() {
        if sensorManager.isAccelerometerAvailable {
            print("-- stopping accelerometer")
            sensorManager.stopAccelerometerUpdates()
        }

        if sensorManager.isDeviceMotionAvailable {
            print("-- stopping deviceMotion")
            sensorManager.stopDeviceMotionUpdates()
        }

        if sensorManager.isGyroAvailable {
            print("-- stopping gyro")
            sensorManager.stopGyroUpdates()
        }

        if sensorManager.isMagnetometerAvailable {
            print("-- stopping magnetometer")
            sensorManager.stopMagnetometerUpdates()
        }

        if self.timer != nil {
            RecordingStateChangeNotification.post(value: false)
            self.timer?.invalidate()
            self.timer = nil

            self.dataQueue.async {
                self.recording?.finishRecording(rows: self.data)
                self.recording = nil
            }
        }

        startStop.setTitle("Start", for: .normal)
    }
}

