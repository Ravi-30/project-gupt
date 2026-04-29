//
//  LatencyMonitor.swift
//  RemoteDesktop
//
//  Tracks end-to-end performance metrics for the video stream
//

import Foundation
import Combine
import os.log

/// Tracks and calculates video stream performance metrics
final class LatencyMonitor: ObservableObject {
    static let shared = LatencyMonitor()
    private let logger = Logger(subsystem: "com.gupt", category: "LatencyMonitor")
    
    struct Metrics {
        var captureLatency: Double = 0      // ms
        var encodeLatency: Double = 0       // ms
        var networkLatency: Double = 0      // ms
        var decodeLatency: Double = 0       // ms
        var renderLatency: Double = 0       // ms
        var totalLatency: Double = 0        // ms
        var fps: Double = 0
    }
    
    @Published private(set) var currentMetrics = Metrics()
    
    private var lastFrameTime = Date()
    private var frameCount = 0
    private var lastFPSUpdate = Date()
    
    private let queue = DispatchQueue(label: "com.gupt.latencymonitor", qos: .utility)
    
    // MARK: - Metrics Collection
    
    /// Reports the latency for a specific phase
    func reportPhaseLatency(phase: Phase, ms: Double) {
        queue.async {
            var metrics = self.currentMetrics
            switch phase {
            case .capture: metrics.captureLatency = ms
            case .encode: metrics.encodeLatency = ms
            case .network: metrics.networkLatency = ms
            case .decode: metrics.decodeLatency = ms
            case .render: metrics.renderLatency = ms
            }
            
            metrics.totalLatency = metrics.captureLatency +
                                   metrics.encodeLatency +
                                   metrics.networkLatency +
                                   metrics.decodeLatency +
                                   metrics.renderLatency
            DispatchQueue.main.async {
                self.currentMetrics = metrics
            }
        }
    }
    
    /// Marks a frame as delivered to update FPS
    func reportFrameDelivered() {
        queue.async {
            self.frameCount += 1
            let now = Date()
            let elapsed = now.timeIntervalSince(self.lastFPSUpdate)
            
            if elapsed >= 1.0 {
                var metrics = self.currentMetrics
                metrics.fps = Double(self.frameCount) / elapsed
                self.frameCount = 0
                self.lastFPSUpdate = now
                DispatchQueue.main.async {
                    self.currentMetrics = metrics
                }
                
                self.logger.debug("Performance: \(String(format: "%.1f", metrics.fps)) FPS, \(String(format: "%.1f", metrics.totalLatency))ms Latency")
            }
        }
    }
    
    // MARK: - Types
    
    enum Phase {
        case capture, encode, network, decode, render
    }
}

// Float formatting extension for debug logs
extension Double {
    func format(as format: String) -> String {
        return String(format: "%\(format)", self)
    }
}
