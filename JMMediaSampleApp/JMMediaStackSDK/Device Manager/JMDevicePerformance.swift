import UIKit
import SystemConfiguration.CaptiveNetwork
import CoreTelephony
import MachO
import Network

public struct JMClientInfoUploader:CustomStringConvertible {
    var cpuPercentage: String
    var ramPercentage: String
    var batteryPercentage: String
    var energyLevel: String
    var networkType: String
    
    public var description: String {
        return """
        CPU: \(cpuPercentage)
        RAM: \(ramPercentage)
        Battery: \(batteryPercentage)
        Energy: \(energyLevel)
        Network: \(networkType)
        """
    }
    
    func toDictionary() -> [String: String] {
        return [
            "cpuPercentage": cpuPercentage,
            "ramPercentage": ramPercentage,
            "batteryPercentage": batteryPercentage,
            "energyLevel": energyLevel,
            "networkType": networkType
        ]
    }
}

public class JMDeviceInfo {
    var networkType = ""
    // Get Device Information
    public static func deviceInfo() -> JMClientInfoUploader {
        let cpuPercentage = getCPUUsage()
        let ramPercentage = getRAMUsage()
        let batteryPercentage = getBatteryInfo()
        let energyLevel = getEnergyLevel()
        let networkStatusChecker = JMNetworkStatusChecker().getCurrentNetworkType()
        
        return JMClientInfoUploader(
            cpuPercentage: cpuPercentage,
            ramPercentage: ramPercentage,
            batteryPercentage: batteryPercentage,
            energyLevel: energyLevel,
            networkType: networkStatusChecker
        )
    }
    
    // Get CPU Usage
    private static func getCPUUsage() -> String {
        var kr: kern_return_t
        var task_info_count: mach_msg_type_number_t
        
        task_info_count = mach_msg_type_number_t(TASK_INFO_MAX)
        var tinfo = [integer_t](repeating: 0, count: Int(task_info_count))
        kr = tinfo.withUnsafeMutableBufferPointer {
            task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0.baseAddress, &task_info_count)
        }
        
        if kr != KERN_SUCCESS {
            return "Unknown"
        }
        
        var basic_info_th: task_basic_info_t
        basic_info_th = tinfo.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: task_basic_info_t.self, capacity: 1) {
                $0.pointee
            }
        }
        
        var thread_list: thread_act_array_t?
        var thread_count: mach_msg_type_number_t = 0
        defer {
            if let thread_list = thread_list {
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: thread_list), vm_size_t(thread_count))
            }
        }
        
        kr = withUnsafeMutablePointer(to: &thread_list) {
            task_threads(mach_task_self_, $0, &thread_count)
        }
        
        if kr != KERN_SUCCESS {
            return "Unknown"
        }
        
        var tot_cpu: Float = 0
        if let thread_list = thread_list {
            for j in 0..<thread_count {
                var thinfo = thread_basic_info()
                var thread_info_count = mach_msg_type_number_t(THREAD_INFO_MAX)
                kr = withUnsafeMutablePointer(to: &thinfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(thread_list[Int(j)], thread_flavor_t(THREAD_BASIC_INFO), $0, &thread_info_count)
                    }
                }
                if kr != KERN_SUCCESS {
                    return "Unknown"
                }
                tot_cpu += Float(thinfo.cpu_usage) / Float(TH_USAGE_SCALE) * 100.0
            }
        }
        
        return String(format: "%.2f%%", tot_cpu)
    }
    
    // Get RAM Usage
    private static func getRAMUsage() -> String {
        let usedMemory = ProcessInfo.processInfo.physicalMemory - getFreeMemory()
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let ramPercentage = (Double(usedMemory) / Double(totalMemory)) * 100
        return String(format: "%.2f%%", ramPercentage)
    }
    
    private static func getFreeMemory() -> UInt64 {
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: vmStat) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let freeMemory = pageSize * UInt64(vmStat.free_count)
            return freeMemory
        }
        return 0
    }
    
    // Get Battery Information
    private static func getBatteryInfo() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        return String(format: "%.0f%%", batteryLevel * 100)
    }
    
    // Get Energy Level (Placeholder)
    private static func getEnergyLevel() -> String {
        // Placeholder: Energy level typically not available on iOS devices for 3rd party apps.
        return "Normal"
    }
    
    // Get Wi-Fi Network Type
    private static func getWiFiNetworkType() -> String? {
        guard let interfaceNames = CNCopySupportedInterfaces() as? [String] else {
            return nil
        }
        
        for interfaceName in interfaceNames {
            guard let info = CNCopyCurrentNetworkInfo(interfaceName as CFString) as? [String: AnyObject] else {
                continue
            }
            if let ssid = info[kCNNetworkInfoKeySSID as String] as? String {
                return "Wi-Fi (\(ssid))"
            }
        }
        return "Wi-Fi"
    }
    
}

class JMDeviceMonitor {
    private var timer: DispatchSourceTimer?
    
    func startDeviceMonitoring(completion: @escaping (JMClientInfoUploader) -> Void) {
        let deviceInformation = JMDeviceInfo.deviceInfo()
        print(deviceInformation)
        completion(deviceInformation)  // Call completion initially with the first data
        
        let queue = DispatchQueue(label: "jm.device.monitoring")
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: 3.0)
        timer?.setEventHandler { [weak self] in
            guard self != nil else { return }
            let deviceInformation = JMDeviceInfo.deviceInfo()
            DispatchQueue.main.async {
                completion(deviceInformation)
            }
        }
        timer?.resume()
    }
    
    func stopDeviceMonitoring() {
        timer?.cancel()
        timer = nil
    }
}

class JMNetworkStatusChecker {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue.global(qos: .background)
    private var currentNetworkType: String = "cellular"
    
    init() {
        setupNetworkMonitor()
    }
    
    private func setupNetworkMonitor() {
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { path in
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    self.currentNetworkType = "Wi-Fi"
                } else if path.usesInterfaceType(.cellular) {
                    self.currentNetworkType = self.getCellularNetworkType()
                } else {
                    self.currentNetworkType = "Other"
                }
            } else {
                self.currentNetworkType = "No Connection"
            }
        }
        monitor?.start(queue: queue)
    }
    
    private func getCellularNetworkType() -> String {
        let networkInfo = CTTelephonyNetworkInfo()
        guard let carrierType = networkInfo.serviceCurrentRadioAccessTechnology?.values.first else {
            return "cellular"
        }
        
        if #available(iOS 14.1, *) {
            switch carrierType {
            case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x:
                return "2G"
            case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD:
                return "3G"
            case CTRadioAccessTechnologyLTE:
                return "4G"
            case CTRadioAccessTechnologyNRNSA, CTRadioAccessTechnologyNR:
                return "5G"
            default:
                return "cellular"
            }
        } else {
            switch carrierType {
            case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x:
                return "2G"
            case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD:
                return "3G"
            case CTRadioAccessTechnologyLTE:
                return "4G"
            default:
                return "cellular"
            }
            // Fallback on earlier versions
        }
    }
    
    public func getCurrentNetworkType() -> String {
        setupNetworkMonitor()
        return currentNetworkType
    }
    
    deinit {
        monitor?.cancel()
    }
}
