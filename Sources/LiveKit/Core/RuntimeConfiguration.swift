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

import WebRTC

/// Runtime configuration manager for the LiveKit SDK
@objc
public class RuntimeConfiguration: NSObject {
    
    // MARK: - Singleton
    
    @objc public static let shared = RuntimeConfiguration()
    
    // MARK: - Properties
    
    private let logger = Logger(label: "RuntimeConfiguration")
    private let queue = DispatchQueue(label: "RuntimeConfiguration", qos: .userInitiated, attributes: .concurrent)
    
    @objc public private(set) var isInitialized = false
    
    // Thread-safe configuration storage
    private var _configurations: [String: Any] = [:]
    private let configurationLock = NSLock()
    
    // Configuration change observers
    private var observers: [String: [ConfigurationObserver]] = [:]
    private let observerLock = NSLock()
    
    // MARK: - Types
    
    public enum ConfigurationKey: String, CaseIterable {
        case backendType = "backend_type"
        case enableLogging = "enable_logging"
        case logLevel = "log_level"
        case enableMetrics = "enable_metrics"
        case enableCrashReporting = "enable_crash_reporting"
        case maxRetryAttempts = "max_retry_attempts"
        case connectionTimeout = "connection_timeout"
        case enableAutoReconnect = "enable_auto_reconnect"
        case enableAudioProcessing = "enable_audio_processing"
        case enableVideoProcessing = "enable_video_processing"
        case enableE2EE = "enable_e2ee"
        case enableScreenSharing = "enable_screen_sharing"
        case enableRecording = "enable_recording"
        case enableTranscription = "enable_transcription"
        case enableAnalytics = "enable_analytics"
        case enablePerformanceMonitoring = "enable_performance_monitoring"
    }
    
    public struct ConfigurationObserver {
        let id: String
        let key: ConfigurationKey
        let callback: (Any?) -> Void
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupDefaultConfigurations()
    }
    
    // MARK: - Public Methods
    
    /// Initialize the runtime configuration
    /// - Parameter initialConfig: Initial configuration dictionary
    @objc public func initialize(with initialConfig: [String: Any]? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.logger.info("Initializing RuntimeConfiguration")
            
            // Apply initial configuration if provided
            if let initialConfig = initialConfig {
                for (key, value) in initialConfig {
                    self.setConfigValue(value, forKey: key)
                }
            }
            
            self.isInitialized = true
            self.logger.info("RuntimeConfiguration initialized successfully")
        }
    }
    
    /// Set a configuration value
    /// - Parameters:
    ///   - value: The value to set
    ///   - key: The configuration key
    @objc public func setConfigValue(_ value: Any?, forKey key: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.configurationLock.lock()
            let oldValue = self._configurations[key]
            self._configurations[key] = value
            self.configurationLock.unlock()
            
            self.logger.info("Configuration updated: \(key) = \(String(describing: value))")
            
            // Notify observers
            self.notifyObservers(forKey: key, oldValue: oldValue, newValue: value)
        }
    }
    
    /// Get a configuration value
    /// - Parameter key: The configuration key
    /// - Returns: The configuration value, or nil if not found
    @objc public func getConfigValue(forKey key: String) -> Any? {
        configurationLock.lock()
        defer { configurationLock.unlock() }
        return _configurations[key]
    }
    
    /// Set a configuration value using the typed key
    /// - Parameters:
    ///   - value: The value to set
    ///   - key: The typed configuration key
    public func setConfigValue(_ value: Any?, forKey key: ConfigurationKey) {
        setConfigValue(value, forKey: key.rawValue)
    }
    
    /// Get a configuration value using the typed key
    /// - Parameter key: The typed configuration key
    /// - Returns: The configuration value, or nil if not found
    public func getConfigValue(forKey key: ConfigurationKey) -> Any? {
        return getConfigValue(forKey: key.rawValue)
    }
    
    /// Add an observer for configuration changes
    /// - Parameters:
    ///   - key: The configuration key to observe
    ///   - callback: The callback to execute when the value changes
    /// - Returns: The observer ID for later removal
    @discardableResult
    public func addObserver(
        forKey key: ConfigurationKey,
        callback: @escaping (Any?) -> Void
    ) -> String {
        let observerId = UUID().uuidString
        let observer = ConfigurationObserver(id: observerId, key: key, callback: callback)
        
        observerLock.lock()
        if observers[key.rawValue] == nil {
            observers[key.rawValue] = []
        }
        observers[key.rawValue]?.append(observer)
        observerLock.unlock()
        
        logger.info("Added observer \(observerId) for key: \(key.rawValue)")
        return observerId
    }
    
    /// Remove an observer
    /// - Parameter observerId: The observer ID to remove
    @objc public func removeObserver(_ observerId: String) {
        observerLock.lock()
        for (key, observerList) in observers {
            observers[key] = observerList.filter { $0.id != observerId }
        }
        observerLock.unlock()
        
        logger.info("Removed observer: \(observerId)")
    }
    
    /// Get all current configuration values
    /// - Returns: Dictionary of all configuration values
    @objc public func getAllConfigurations() -> [String: Any] {
        configurationLock.lock()
        defer { configurationLock.unlock() }
        return _configurations
    }
    
    /// Reset configuration to default values
    @objc public func resetToDefaults() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.logger.info("Resetting configuration to defaults")
            
            self.configurationLock.lock()
            self._configurations.removeAll()
            self.configurationLock.unlock()
            
            self.setupDefaultConfigurations()
        }
    }
    
    /// Validate the current configuration
    /// - Returns: Tuple with validation result and any errors
    public func validateConfiguration() -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []
        
        // Check required configurations
        if getConfigValue(forKey: .backendType) == nil {
            errors.append("Backend type not configured")
        }
        
        if getConfigValue(forKey: .connectionTimeout) == nil {
            errors.append("Connection timeout not configured")
        }
        
        // Validate timeout value
        if let timeout = getConfigValue(forKey: .connectionTimeout) as? TimeInterval {
            if timeout <= 0 {
                errors.append("Connection timeout must be greater than 0")
            }
        }
        
        // Validate retry attempts
        if let retries = getConfigValue(forKey: .maxRetryAttempts) as? Int {
            if retries < 0 {
                errors.append("Max retry attempts cannot be negative")
            }
        }
        
        return (errors.isEmpty, errors)
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultConfigurations() {
        let defaults: [ConfigurationKey: Any] = [
            .backendType: BackendType.liveKit.rawValue,
            .enableLogging: true,
            .logLevel: "info",
            .enableMetrics: true,
            .enableCrashReporting: false,
            .maxRetryAttempts: 3,
            .connectionTimeout: 30.0,
            .enableAutoReconnect: true,
            .enableAudioProcessing: true,
            .enableVideoProcessing: true,
            .enableE2EE: false,
            .enableScreenSharing: true,
            .enableRecording: false,
            .enableTranscription: false,
            .enableAnalytics: true,
            .enablePerformanceMonitoring: true
        ]
        
        for (key, value) in defaults {
            setConfigValue(value, forKey: key)
        }
        
        logger.info("Default configurations applied")
    }
    
    private func notifyObservers(forKey key: String, oldValue: Any?, newValue: Any?) {
        observerLock.lock()
        let keyObservers = observers[key] ?? []
        observerLock.unlock()
        
        for observer in keyObservers {
            observer.callback(newValue)
        }
        
        if !keyObservers.isEmpty {
            logger.debug("Notified \(keyObservers.count) observers for key: \(key)")
        }
    }
}

// MARK: - Convenience Extensions

extension RuntimeConfiguration {
    
    /// Convenience method to get boolean configuration
    /// - Parameter key: The configuration key
    /// - Returns: Boolean value, defaults to false if not found or not boolean
    public func getBool(forKey key: ConfigurationKey) -> Bool {
        return getConfigValue(forKey: key) as? Bool ?? false
    }
    
    /// Convenience method to get integer configuration
    /// - Parameter key: The configuration key
    /// - Returns: Integer value, defaults to 0 if not found or not integer
    public func getInt(forKey key: ConfigurationKey) -> Int {
        return getConfigValue(forKey: key) as? Int ?? 0
    }
    
    /// Convenience method to get double configuration
    /// - Parameter key: The configuration key
    /// - Returns: Double value, defaults to 0.0 if not found or not double
    public func getDouble(forKey key: ConfigurationKey) -> Double {
        return getConfigValue(forKey: key) as? Double ?? 0.0
    }
    
    /// Convenience method to get string configuration
    /// - Parameter key: The configuration key
    /// - Returns: String value, defaults to empty string if not found or not string
    public func getString(forKey key: ConfigurationKey) -> String {
        return getConfigValue(forKey: key) as? String ?? ""
    }
} 