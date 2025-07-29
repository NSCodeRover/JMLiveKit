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

import LiveKitWebRTC

/// Backend types supported by the SDK
public enum BackendType: Int, CaseIterable {
    case liveKit = 0
    case mediaSoup = 1
    
    public var description: String {
        switch self {
        case .liveKit:
            return "LiveKit"
        case .mediaSoup:
            return "MediaSoup"
        }
    }
}

/// Runtime configuration for backend switching
public class BackendConfiguration: NSObject {
    public let backendType: BackendType
    public let isEnabled: Bool
    public let priority: Int
    
    public init(backendType: BackendType, isEnabled: Bool = true, priority: Int = 0) {
        self.backendType = backendType
        self.isEnabled = isEnabled
        self.priority = priority
        super.init()
    }
}

/// Manages runtime switching between LiveKit and MediaSoup backends
public class BackendManager: NSObject {
    
    // MARK: - Singleton
    
    public static let shared = BackendManager()
    
    // MARK: - Properties
    
    private let logger = Logger(label: "BackendManager")
    private let queue = DispatchQueue(label: "BackendManager", qos: .userInitiated)
    
    public private(set) var currentBackend: BackendType = .liveKit
    public private(set) var availableBackends: [BackendType] = []
    
    private var configurations: [BackendType: BackendConfiguration] = [:]
    private var isInitialized = false
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupDefaultConfigurations()
        detectAvailableBackends()
    }
    
    // MARK: - Public Methods
    
    /// Initialize the backend manager with custom configurations
    /// - Parameter configs: Array of backend configurations
    public func initialize(with configs: [BackendConfiguration]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.logger.info("Initializing BackendManager with \(configs.count) configurations")
            
            // Update configurations
            for config in configs {
                self.configurations[config.backendType] = config
            }
            
            // Detect available backends
            self.detectAvailableBackends()
            
            // Select the best available backend
            self.selectBestBackend()
            
            self.isInitialized = true
            self.logger.info("BackendManager initialized. Current backend: \(self.currentBackend.description)")
        }
    }
    
    /// Switch to a specific backend at runtime
    /// - Parameters:
    ///   - backendType: The backend type to switch to
    ///   - completion: Completion handler called when switching is complete
    public func switchToBackend(_ backendType: BackendType, completion: @escaping (Bool, Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(false, NSError(domain: "BackendManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "BackendManager not available"]))
                return
            }
            
            self.logger.info("Attempting to switch to backend: \(backendType.description)")
            
            // Validate backend availability
            guard self.availableBackends.contains(backendType) else {
                let error = NSError(domain: "BackendManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Backend \(backendType.description) is not available"])
                self.logger.error("Backend switch failed: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            // Validate configuration
            guard let config = self.configurations[backendType], config.isEnabled else {
                let error = NSError(domain: "BackendManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Backend \(backendType.description) is not enabled"])
                self.logger.error("Backend switch failed: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            // Perform the switch
            do {
                try self.performBackendSwitch(to: backendType)
                self.currentBackend = backendType
                self.logger.info("Successfully switched to backend: \(backendType.description)")
                completion(true, nil)
            } catch {
                self.logger.error("Backend switch failed: \(error.localizedDescription)")
                completion(false, error)
            }
        }
    }
    
    /// Get the current backend configuration
    /// - Parameter backendType: The backend type
    /// - Returns: The configuration for the specified backend, or nil if not found
    public func getConfiguration(for backendType: BackendType) -> BackendConfiguration? {
        return configurations[backendType]
    }
    
    /// Update the configuration for a specific backend
    /// - Parameter config: The new configuration
    public func updateConfiguration(_ config: BackendConfiguration) {
        queue.async { [weak self] in
            self?.configurations[config.backendType] = config
            self?.logger.info("Updated configuration for backend: \(config.backendType.description)")
        }
    }
    
    /// Check if a backend is available and enabled
    /// - Parameter backendType: The backend type to check
    /// - Returns: True if the backend is available and enabled
    public func isBackendAvailable(_ backendType: BackendType) -> Bool {
        return availableBackends.contains(backendType) && 
               configurations[backendType]?.isEnabled == true
    }
    
    /// Get the best available backend based on priority
    /// - Returns: The best available backend, or nil if none are available
    public func getBestAvailableBackend() -> BackendType? {
        let sortedConfigs = configurations.values
            .filter { availableBackends.contains($0.backendType) && $0.isEnabled }
            .sorted { $0.priority > $1.priority }
        
        return sortedConfigs.first?.backendType
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultConfigurations() {
        configurations[.liveKit] = BackendConfiguration(backendType: .liveKit, isEnabled: true, priority: 100)
        configurations[.mediaSoup] = BackendConfiguration(backendType: .mediaSoup, isEnabled: true, priority: 50)
    }
    
    private func detectAvailableBackends() {
        var available: [BackendType] = []
        
        // Check LiveKit availability
        if isLiveKitAvailable() {
            available.append(.liveKit)
            logger.info("LiveKit backend detected and available")
        } else {
            logger.warning("LiveKit backend not available")
        }
        
        // Check MediaSoup availability
        if isMediaSoupAvailable() {
            available.append(.mediaSoup)
            logger.info("MediaSoup backend detected and available")
        } else {
            logger.warning("MediaSoup backend not available")
        }
        
        availableBackends = available
        logger.info("Available backends: \(available.map { $0.description }.joined(separator: ", "))")
    }
    
    private func isLiveKitAvailable() -> Bool {
        // Check if LiveKit WebRTC framework is available
        return Bundle.allBundles.contains { bundle in
            bundle.bundleIdentifier?.contains("LiveKitWebRTC") == true
        }
    }
    
    private func isMediaSoupAvailable() -> Bool {
        // Check if MediaSoup framework is available
        // This would need to be implemented based on your MediaSoup integration
        return false // Placeholder - implement based on your MediaSoup setup
    }
    
    private func selectBestBackend() {
        guard let bestBackend = getBestAvailableBackend() else {
            logger.error("No available backends found")
            return
        }
        
        currentBackend = bestBackend
        logger.info("Selected best available backend: \(bestBackend.description)")
    }
    
    private func performBackendSwitch(to backendType: BackendType) throws {
        logger.info("Performing backend switch to: \(backendType.description)")
        
        // Validate current state
        guard isInitialized else {
            throw NSError(domain: "BackendManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "BackendManager not initialized"])
        }
        
        // Perform backend-specific initialization
        switch backendType {
        case .liveKit:
            try initializeLiveKitBackend()
        case .mediaSoup:
            try initializeMediaSoupBackend()
        }
        
        logger.info("Backend switch completed successfully")
    }
    
    private func initializeLiveKitBackend() throws {
        logger.info("Initializing LiveKit backend")
        
        // Add any LiveKit-specific initialization here
        // For example, setting up WebRTC configuration, audio processing, etc.
        
        // Validate WebRTC availability
        guard isLiveKitAvailable() else {
            throw NSError(domain: "BackendManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "LiveKit WebRTC not available"])
        }
        
        logger.info("LiveKit backend initialized successfully")
    }
    
    private func initializeMediaSoupBackend() throws {
        logger.info("Initializing MediaSoup backend")
        
        // Add any MediaSoup-specific initialization here
        // This would depend on your MediaSoup integration
        
        guard isMediaSoupAvailable() else {
            throw NSError(domain: "BackendManager", code: -6, userInfo: [NSLocalizedDescriptionKey: "MediaSoup not available"])
        }
        
        logger.info("MediaSoup backend initialized successfully")
    }
}

// MARK: - Runtime Backend Detection

extension BackendManager {
    
    /// Get detailed information about the current backend state
    public func getBackendInfo() -> [String: Any] {
        return [
            "currentBackend": currentBackend.description,
            "availableBackends": availableBackends.map { $0.description },
            "isInitialized": isInitialized,
            "configurations": configurations.mapValues { [
                "enabled": $0.isEnabled,
                "priority": $0.priority
            ] }
        ]
    }
    
    /// Validate the current backend configuration
    public func validateConfiguration() -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []
        
        if !isInitialized {
            errors.append("BackendManager not initialized")
        }
        
        if availableBackends.isEmpty {
            errors.append("No backends available")
        }
        
        if !availableBackends.contains(currentBackend) {
            errors.append("Current backend (\(currentBackend.description)) is not available")
        }
        
        return (errors.isEmpty, errors)
    }
} 