// Services/Logging.swift
import Foundation
import os

enum Log {
    static let subsystem: String = Bundle.main.bundleIdentifier ?? "tech.systemsmystery.kuna"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let watch = Logger(subsystem: subsystem, category: "watch")
    static let widget = Logger(subsystem: subsystem, category: "widget")
}

enum LogConfig {
    #if DEBUG
    static let verboseNetwork = true
    #else
    static let verboseNetwork = false
    #endif
}

