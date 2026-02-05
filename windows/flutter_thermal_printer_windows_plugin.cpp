#include "flutter_thermal_printer_windows_plugin.h"
#include "bluetooth_winrt.h"

#include <windows.h>
#include <VersionHelpers.h>

#include <flutter/method_channel.h>

#include <exception>
#include <fstream>
#include <sstream>

namespace {
void PluginLog(const std::string& msg) {
  OutputDebugStringA("[ThermalPlugin] ");
  OutputDebugStringA(msg.c_str());
  OutputDebugStringA("\n");
  char path[MAX_PATH];
  if (GetTempPathA(MAX_PATH, path) > 0) {
    std::string logpath = std::string(path) + "flutter_thermal_printer_debug.log";
    std::ofstream f(logpath, std::ios::app);
    if (f) {
      f << "[ThermalPlugin] " << msg << "\n";
      f.flush();
    }
  }
}
#define PLUGIN_LOG(x) do { std::ostringstream _s; _s << x; PluginLog(_s.str()); } while(0)
}  // namespace
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace flutter_thermal_printer_windows {

namespace {

constexpr int kConnectionStateDisconnected = 0;
constexpr int kConnectionStateConnecting = 1;
constexpr int kConnectionStateConnected = 2;
constexpr int kConnectionStateDisconnecting = 3;

flutter::EncodableValue StringToEncodable(const std::string& s) {
  return flutter::EncodableValue(std::string(s));
}

flutter::EncodableMap SppDeviceToEncodableMap(const SppDeviceInfo& info) {
  flutter::EncodableMap m;
  m[flutter::EncodableValue("id")] = StringToEncodable(info.id);
  m[flutter::EncodableValue("name")] = StringToEncodable(info.name);
  m[flutter::EncodableValue("macAddress")] = StringToEncodable(info.mac_address);
  m[flutter::EncodableValue("signalStrength")] = flutter::EncodableValue(info.signal_strength);
  m[flutter::EncodableValue("isPaired")] = flutter::EncodableValue(info.is_paired);
  m[flutter::EncodableValue("connectionState")] = flutter::EncodableValue(
      info.is_connected ? kConnectionStateConnected : kConnectionStateDisconnected);
  return m;
}

std::string GetPrinterIdFromArgs(const flutter::EncodableValue* args_value) {
  const auto* args = args_value ? std::get_if<flutter::EncodableMap>(args_value) : nullptr;
  if (!args) return "";
  auto it = args->find(flutter::EncodableValue("id"));
  if (it == args->end()) {
    it = args->find(flutter::EncodableValue("macAddress"));
  }
  if (it == args->end()) return "";
  const auto* s = std::get_if<std::string>(&it->second);
  return s ? *s : "";
}

}  // namespace

void FlutterThermalPrinterWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_thermal_printer_windows",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterThermalPrinterWindowsPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterThermalPrinterWindowsPlugin::FlutterThermalPrinterWindowsPlugin() {
  BluetoothWinRtInit();
}

FlutterThermalPrinterWindowsPlugin::~FlutterThermalPrinterWindowsPlugin() {}

void FlutterThermalPrinterWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else if (method_call.method_name().compare("scanForPrinters") == 0) {
    PLUGIN_LOG("========== scanForPrinters START (async) ==========");
    PLUGIN_LOG("scanForPrinters: posting async, returning immediately");
    auto result_holder = std::make_shared<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(
        std::move(result));
    BluetoothFindAllSppDevicesAsync([result_holder](std::vector<SppDeviceInfo> devices) {
      auto& res = *result_holder;
      if (!res) return;
      try {
        PLUGIN_LOG("scanForPrinters: async callback got " << devices.size() << " devices");
        flutter::EncodableList list;
        for (size_t i = 0; i < devices.size(); i++) {
          try {
            list.push_back(flutter::EncodableValue(SppDeviceToEncodableMap(devices[i])));
          } catch (const std::exception& e) {
            PLUGIN_LOG("scanForPrinters: skip device " << i << " encode error: " << e.what());
          } catch (...) {
            PLUGIN_LOG("scanForPrinters: skip device " << i << " encode unknown error");
          }
        }
        PLUGIN_LOG("scanForPrinters: calling result->Success with " << list.size() << " devices");
        res->Success(flutter::EncodableValue(list));
      } catch (const std::exception& e) {
        PLUGIN_LOG("scanForPrinters: async callback ERROR: " << e.what());
        res->Error("ScanFailed", e.what());
      } catch (...) {
        PLUGIN_LOG("scanForPrinters: async callback unknown ERROR");
        res->Error("ScanFailed", "Unknown error encoding scan results");
      }
      PLUGIN_LOG("scanForPrinters: async complete");
    });
  } else if (method_call.method_name().compare("pairDevice") == 0) {
    const flutter::EncodableValue* args_value = method_call.arguments();
    const auto* args =
        args_value ? std::get_if<flutter::EncodableMap>(args_value) : nullptr;
    if (!args) {
      result->Error("InvalidArguments", "Expected printer map");
      return;
    }
    std::string id = GetPrinterIdFromArgs(args_value);
    if (id.empty()) {
      result->Error("InvalidArguments", "Expected printer with id");
      return;
    }
    flutter::EncodableValue printer_copy(*args);
    auto result_holder = std::make_shared<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(
        std::move(result));
    // Use STA async (non-blocking Completed) so pairing UI can appear.
    BluetoothPairDeviceAsyncSta(id, [result_holder, printer_copy](bool paired) {
      auto& res = *result_holder;
      if (!res) return;
      try {
        flutter::EncodableMap out;
        out[flutter::EncodableValue("isPaired")] = flutter::EncodableValue(paired);
        out[flutter::EncodableValue("printer")] = printer_copy;
        res->Success(flutter::EncodableValue(out));
      } catch (const std::exception& e) {
        res->Error("PairFailed", e.what());
      } catch (...) {
        res->Error("PairFailed", "Unknown error");
      }
    });
  } else if (method_call.method_name().compare("unpairDevice") == 0) {
    const flutter::EncodableValue* args_value = method_call.arguments();
    std::string id = GetPrinterIdFromArgs(args_value);
    if (id.empty()) {
      result->Error("InvalidArguments", "Expected printer with id");
      return;
    }
    auto result_holder = std::make_shared<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(
        std::move(result));
    BluetoothUnpairDeviceAsync(id, [result_holder](bool ok) {
      auto& res = *result_holder;
      if (!res) return;
      if (ok) {
        res->Success();
      } else {
        res->Error("UnpairFailed", "Failed to unpair device");
      }
    });
  } else if (method_call.method_name().compare("connectToDevice") == 0) {
    const flutter::EncodableValue* args_value = method_call.arguments();
    std::string id = GetPrinterIdFromArgs(args_value);
    if (id.empty()) {
      result->Error("InvalidArguments", "Expected printer with id");
      return;
    }
    auto result_holder = std::make_shared<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(
        std::move(result));
    BluetoothConnectAsync(id, [result_holder](bool connected) {
      auto& res = *result_holder;
      if (!res) return;
      try {
        flutter::EncodableMap out;
        out[flutter::EncodableValue("isConnected")] = flutter::EncodableValue(connected);
        res->Success(flutter::EncodableValue(out));
      } catch (const std::exception& e) {
        res->Error("ConnectFailed", e.what());
      } catch (...) {
        res->Error("ConnectFailed", "Unknown error");
      }
    });
  } else if (method_call.method_name().compare("disconnectFromDevice") == 0) {
    const flutter::EncodableValue* args_value = method_call.arguments();
    std::string id = GetPrinterIdFromArgs(args_value);
    if (id.empty()) {
      result->Error("InvalidArguments", "Expected printer with id");
      return;
    }
    BluetoothDisconnect(id);
    result->Success();
  } else if (method_call.method_name().compare("getConnectionState") == 0) {
    const flutter::EncodableValue* args_value = method_call.arguments();
    const auto* args =
        args_value ? std::get_if<flutter::EncodableMap>(args_value) : nullptr;
    std::string id;
    if (args) {
      auto it = args->find(flutter::EncodableValue("printerId"));
      if (it != args->end()) {
        const auto* s = std::get_if<std::string>(&it->second);
        if (s) id = *s;
      }
    }
    int state = BluetoothIsConnected(id) ? kConnectionStateConnected : kConnectionStateDisconnected;
    result->Success(flutter::EncodableValue(state));
  } else if (method_call.method_name().compare("sendRawCommands") == 0) {
    const flutter::EncodableValue* args_value = method_call.arguments();
    const auto* args =
        args_value ? std::get_if<flutter::EncodableMap>(args_value) : nullptr;
    if (!args) {
      result->Error("InvalidArguments", "Expected printer and bytes");
      return;
    }
    auto printer_it = args->find(flutter::EncodableValue("printer"));
    auto bytes_it = args->find(flutter::EncodableValue("bytes"));
    if (printer_it == args->end() || bytes_it == args->end()) {
      result->Error("InvalidArguments", "Expected printer and bytes");
      return;
    }
    const auto* printer_map = std::get_if<flutter::EncodableMap>(&printer_it->second);
    const auto* bytes_list = std::get_if<flutter::EncodableList>(&bytes_it->second);
    if (!printer_map || !bytes_list) {
      result->Error("InvalidArguments", "Invalid printer or bytes");
      return;
    }
    flutter::EncodableValue printer_encodable(*printer_map);
    std::string id = GetPrinterIdFromArgs(&printer_encodable);
    std::vector<uint8_t> bytes;
    for (const auto& v : *bytes_list) {
      const auto* i = std::get_if<int32_t>(&v);
      if (i) bytes.push_back(static_cast<uint8_t>(*i & 0xFF));
    }
    bool ok = BluetoothSend(id, bytes.data(), bytes.size());
    if (ok) {
      result->Success();
    } else {
      result->Error("SendFailed", "Failed to send data to printer");
    }
  } else if (method_call.method_name().compare("getPairedPrinters") == 0) {
    auto result_holder = std::make_shared<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(
        std::move(result));
    BluetoothFindAllSppDevicesAsync([result_holder](std::vector<SppDeviceInfo> devices) {
      auto& res = *result_holder;
      if (!res) return;
      flutter::EncodableList list;
      for (const auto& d : devices) {
        if (d.is_paired) {
          list.push_back(flutter::EncodableValue(SppDeviceToEncodableMap(d)));
        }
      }
      res->Success(flutter::EncodableValue(list));
    });
  } else if (method_call.method_name().compare("getPrinterCapabilities") == 0) {
    flutter::EncodableMap out;
    out[flutter::EncodableValue("maxPaperWidth")] = flutter::EncodableValue(58);
    out[flutter::EncodableValue("supportsCutting")] = flutter::EncodableValue(true);
    out[flutter::EncodableValue("supportsImages")] = flutter::EncodableValue(true);
    out[flutter::EncodableValue("supportsPartialCut")] = flutter::EncodableValue(false);
    result->Success(flutter::EncodableValue(out));
  } else if (method_call.method_name().compare("getPrinterStatus") == 0) {
    const flutter::EncodableValue* args_value = method_call.arguments();
    std::string id = GetPrinterIdFromArgs(args_value);
    bool connected = BluetoothIsConnected(id);
    flutter::EncodableMap out;
    out[flutter::EncodableValue("isConnected")] = flutter::EncodableValue(connected);
    out[flutter::EncodableValue("isPaperOut")] = flutter::EncodableValue(false);
    out[flutter::EncodableValue("isCoverOpen")] = flutter::EncodableValue(false);
    out[flutter::EncodableValue("isError")] = flutter::EncodableValue(false);
    result->Success(flutter::EncodableValue(out));
  } else {
    result->NotImplemented();
  }
}

}  // namespace flutter_thermal_printer_windows
