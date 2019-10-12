// Copyright © 2019 Brad Howes. All rights reserved.

import os

struct Logging {
    static let subsystem = "com.braysoftware.MotionCategorizer"

    static func logger(_ category: String) -> OSLog {
        return OSLog(subsystem: subsystem, category: category)
    }
}
