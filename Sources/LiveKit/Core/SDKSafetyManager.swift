/*
 * Copyright 2025 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import Logging
import Network

import WebRTC

/// Comprehensive safety manager for the LiveKit SDK
class SDKSafetyManager: NSObject {
    
    // MARK: - Singleton
    
    static let shared = SDKSafetyManager()
    
    // MARK: - Properties
    
    private let logger = Logger(label: "SDKSafetyManager")
    private let queue = DispatchQueue(label: "SDKSafetyManager", qos: .userInitiated)
    
    var isInitialized = false
    var isSafeToUse = false
    
    private var safetyChecks: [SafetyCheck] = []
    private var errorHandlers: [ErrorHandler] = []
    
    // MARK: - Types
    
    public enum SafetyLevel: Int {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3
    }
    
    public enum SafetyStatus: Int {
        case unknown = 0
        case safe = 1
        case warning = 2
        case unsafe = 3
        case critical = 4
    }
    
    public struct SafetyCheck {
        let name: String
        let level: SafetyLevel
        let check: () -> Bool
        let description: String
    }
    
    public struct ErrorHandler {
        let errorType: String
        let handler: (Error) -> Void
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupDefaultSafetyChecks()
        setupDefaultErrorHandlers()
    }
    
    // MARK: - Public Methods
    
    /// Initialize the safety manager
    /// - Parameter enableStrictMode: Whether to enable strict safety checks
    func initialize(enableStrictMode: Bool = false) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.logger.info("Initializing SDKSafetyManager with strict mode: \(enableStrictMode)")
            
            // Perform all safety checks
            let results = self.performAllSafetyChecks()
            
            // Determine overall safety status
            let status = self.determineSafetyStatus(results)
            
            self.isSafeToUse = status == .safe || status == .warning
            self.isInitialized = true
            
            self.logger.info("SDKSafetyManager initialized. Safety status: \(status.rawValue), Safe to use: \(self.isSafeToUse)")
            
            // Log any warnings or errors
            for result in results where result.status != .safe {
                self.logger.warning("Safety check '\(result.name)' failed: \(result.description)")
            }
        }
    }
    
    public func performSafetyCheck(
        for operation: String,
        level: SafetyLevel,
        completion: @escaping (SafetyStatus, [String]) -> Void
    ) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(.unknown, ["Safety manager not available"])
                return
            }
            
            self.logger.info("Performing safety check for operation: \(operation), level: \(level.rawValue)")
            
            let results = self.performAllSafetyChecks()
            let status = self.determineSafetyStatus(results)
            
            // Filter results based on required level
            let relevantResults = results.filter { $0.level.rawValue >= level.rawValue }
            let warnings = relevantResults.compactMap { result in
                result.status != .safe ? "\(result.name): \(result.description)" : nil
            }
            
            completion(status, warnings)
        }
    }
    
    /// Add a custom safety check
    /// - Parameter check: The safety check to add
    func addSafetyCheck(_ check: SafetyCheck) {
        queue.async { [weak self] in
            self?.safetyChecks.append(check)
            self?.logger.info("Added custom safety check: \(check.name)")
        }
    }
    
    /// Add a custom error handler
    /// - Parameter handler: The error handler to add
    func addErrorHandler(_ handler: ErrorHandler) {
        queue.async { [weak self] in
            self?.errorHandlers.append(handler)
            self?.logger.info("Added custom error handler for: \(handler.errorType)")
        }
    }
    
    /// Handle an error with registered error handlers
    /// - Parameter error: The error to handle
    func handleError(_ error: Error) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.logger.error("Handling error: \(error.localizedDescription)")
            
            // Find appropriate error handler
            let errorType = String(describing: type(of: error))
            if let handler = self.errorHandlers.first(where: { $0.errorType == errorType }) {
                handler.handler(error)
            } else {
                // Use default error handling
                self.handleDefaultError(error)
            }
        }
    }
    
    /// Get current safety status and details
    /// - Returns: Dictionary with safety information
    func getSafetyStatus() -> [String: Any] {
        let results = performAllSafetyChecks()
        let status = determineSafetyStatus(results)
        
        return [
            "status": status.rawValue,
            "isSafeToUse": isSafeToUse,
            "isInitialized": isInitialized,
            "checks": results.map { [
                "name": $0.name,
                "level": $0.level.rawValue,
                "status": $0.status.rawValue,
                "description": $0.description
            ] }
        ]
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultSafetyChecks() {
        safetyChecks = [
            SafetyCheck(
                name: "Backend Availability",
                level: .critical,
                check: { BackendManager.shared.isBackendAvailable(.liveKit) },
                description: "LiveKit backend must be available"
            ),
            SafetyCheck(
                name: "WebRTC Framework",
                level: .critical,
                check: { self.isWebRTCFrameworkAvailable() },
                description: "WebRTC framework must be available"
            ),
            SafetyCheck(
                name: "Network Connectivity",
                level: .high,
                check: { self.isNetworkAvailable() },
                description: "Network connectivity should be available"
            ),
            SafetyCheck(
                name: "Audio Permissions",
                level: .medium,
                check: { self.areAudioPermissionsGranted() },
                description: "Audio permissions should be granted"
            ),
            SafetyCheck(
                name: "Memory Usage",
                level: .low,
                check: { self.isMemoryUsageAcceptable() },
                description: "Memory usage should be within acceptable limits"
            )
        ]
    }
    
    private func setupDefaultErrorHandlers() {
        errorHandlers = [
            ErrorHandler(errorType: "NetworkError") { error in
                self.logger.error("Network error handled: \(error.localizedDescription)")
                // Implement network error recovery
            },
            ErrorHandler(errorType: "AudioError") { error in
                self.logger.error("Audio error handled: \(error.localizedDescription)")
                // Implement audio error recovery
            },
            ErrorHandler(errorType: "WebRTCError") { error in
                self.logger.error("WebRTC error handled: \(error.localizedDescription)")
                // Implement WebRTC error recovery
            }
        ]
    }
    
    private func performAllSafetyChecks() -> [(name: String, status: SafetyStatus, description: String, level: SafetyLevel)] {
        return safetyChecks.map { check in
            let passed = check.check()
            let status: SafetyStatus = passed ? .safe : .unsafe
            return (name: check.name, status: status, description: check.description, level: check.level)
        }
    }
    
    private func determineSafetyStatus(_ results: [(name: String, status: SafetyStatus, description: String, level: SafetyLevel)]) -> SafetyStatus {
        let criticalFailures = results.filter { $0.status == .unsafe && $0.level == .critical }.count
        
        let highFailures = results.filter { $0.status == .unsafe && $0.level == .high }.count
        
        if criticalFailures > 0 {
            return .critical
        } else if highFailures > 0 {
            return .unsafe
        } else if results.contains(where: { $0.status == .unsafe }) {
            return .warning
        } else {
            return .safe
        }
    }
    
    private func isWebRTCFrameworkAvailable() -> Bool {
        return Bundle.allBundles.contains { bundle in
            bundle.bundleIdentifier?.contains("LiveKitWebRTC") == true
        }
    }
    
    private func isNetworkAvailable() -> Bool {
        // Simple network check - in production, you might want more sophisticated checking
        return true
    }
    
    private func areAudioPermissionsGranted() -> Bool {
        // Check audio permissions - this would need to be implemented based on your app's permission handling
        return true
    }
    
    private func isMemoryUsageAcceptable() -> Bool {
        // Check memory usage - this would need to be implemented based on your app's requirements
        return true
    }
    
    private func handleDefaultError(_ error: Error) {
        logger.error("Default error handling for: \(error.localizedDescription)")
        
        // Implement default error handling logic
        // This could include:
        // - Logging the error
        // - Notifying the user
        // - Attempting recovery
        // - Reporting to analytics
    }
}

// MARK: - Convenience Extensions

extension SDKSafetyManager {
    
    /// Convenience method to check if it's safe to perform an operation
    /// - Parameters:
    ///   - operation: The operation name
    ///   - level: The required safety level
    ///   - completion: Completion handler with safety result
    func isSafeToPerform(
        _ operation: String,
        level: SafetyLevel = .medium,
        completion: @escaping (Bool, [String]) -> Void
    ) {
        performSafetyCheck(for: operation, level: level) { status, warnings in
            completion(status == .safe || status == .warning, warnings)
        }
    }
    
    /// Synchronous safety check (use with caution)
    /// - Parameters:
    ///   - operation: The operation name
    ///   - level: The required safety level
    /// - Returns: Whether it's safe to perform the operation
    func isSafeToPerformSync(_ operation: String, level: SafetyLevel = .medium) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        
        isSafeToPerform(operation, level: level) { safe, _ in
            result = safe
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
} 