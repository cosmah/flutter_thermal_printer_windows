#ifndef FLUTTER_PLUGIN_BLUETOOTH_WINRT_H_
#define FLUTTER_PLUGIN_BLUETOOTH_WINRT_H_

#include <functional>
#include <string>
#include <vector>
#include <unordered_map>
#include <cstdint>

namespace flutter_thermal_printer_windows {

struct SppDeviceInfo {
  std::string id;
  std::string name;
  std::string mac_address;
  int signal_strength;
  bool is_paired;
  bool is_connected = false;
};

/// Initialize WinRT (call once, e.g. from plugin constructor).
void BluetoothWinRtInit();

/// Discover SPP (Serial Port Profile) Bluetooth devices (thermal printers).
/// Returns empty vector on error or if no devices.
std::vector<SppDeviceInfo> BluetoothFindAllSppDevices();

/// Async version: runs scan on worker thread, invokes callback with result.
/// Use this to avoid blocking the method channel/platform thread.
void BluetoothFindAllSppDevicesAsync(std::function<void(std::vector<SppDeviceInfo>)> callback);

/// Pair with device by DeviceInformation Id. Returns true if paired.
bool BluetoothPairDevice(const std::string& device_id);

/// Async version: runs on MTA worker, invokes callback(bool paired).
void BluetoothPairDeviceAsync(const std::string& device_id,
                              std::function<void(bool)> callback);

/// Async version for STA (platform) thread: uses Completed handlers, no .get().
/// Call from platform thread to allow pairing UI to appear. Invokes callback(bool paired).
void BluetoothPairDeviceAsyncSta(const std::string& device_id,
                                 std::function<void(bool)> callback);

/// Unpair device by Id. Returns true on success.
bool BluetoothUnpairDevice(const std::string& device_id);

/// Async version: runs on worker, invokes callback(bool ok).
void BluetoothUnpairDeviceAsync(const std::string& device_id,
                                std::function<void(bool)> callback);

/// Connect to SPP service. Returns true if connected. Socket stored internally.
bool BluetoothConnect(const std::string& device_id);

/// Async version: runs on worker, invokes callback(bool connected).
void BluetoothConnectAsync(const std::string& device_id,
                           std::function<void(bool)> callback);

/// Disconnect and close socket for device.
void BluetoothDisconnect(const std::string& device_id);

/// True if we have an open socket for this device.
bool BluetoothIsConnected(const std::string& device_id);

/// Send raw bytes to the device. Returns true on success.
bool BluetoothSend(const std::string& device_id, const uint8_t* data, size_t size);

/// Async version: runs on MTA worker, invokes callback(bool ok).
void BluetoothSendAsync(const std::string& device_id,
                        const uint8_t* data,
                        size_t size,
                        std::function<void(bool)> callback);

}  // namespace flutter_thermal_printer_windows

#endif  // FLUTTER_PLUGIN_BLUETOOTH_WINRT_H_
