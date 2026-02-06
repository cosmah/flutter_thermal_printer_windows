#include "bluetooth_winrt.h"

#include <windows.h>

#include <cstdio>
#include <fstream>
#include <sstream>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Bluetooth.Rfcomm.h>
#include <winrt/Windows.Networking.Sockets.h>
#include <winrt/Windows.Storage.Streams.h>

#include <algorithm>
#include <condition_variable>
#include <cstring>
#include <exception>
#include <functional>
#include <mutex>
#include <thread>

namespace flutter_thermal_printer_windows {

namespace winrt_win = winrt::Windows;

static std::mutex g_log_mutex;

static void BtLog(const char* msg) {
  std::lock_guard<std::mutex> lock(g_log_mutex);
  OutputDebugStringA("[BtWinRt] ");
  OutputDebugStringA(msg);
  OutputDebugStringA("\n");
  char path[MAX_PATH];
  if (GetTempPathA(MAX_PATH, path) > 0) {
    std::string logpath = std::string(path) + "flutter_thermal_printer_debug.log";
    std::ofstream f(logpath, std::ios::app);
    if (f) {
      f << "[BtWinRt] " << msg << "\n";
      f.flush();
    }
  }
}

static void BtLog(const std::string& msg) {
  BtLog(msg.c_str());
}

#define BT_LOG(x) do { std::ostringstream _s; _s << x; BtLog(_s.str()); } while(0)
#ifdef _DEBUG
#define BT_VERBOSE(x) BT_LOG(x)
#else
#define BT_VERBOSE(x) ((void)0)
#endif

static std::unordered_map<std::string, winrt_win::Networking::Sockets::StreamSocket> g_sockets;
/// Reuse one DataWriter per socket - creating multiple on same stream can fail.
static std::unordered_map<std::string, winrt_win::Storage::Streams::DataWriter> g_writers;
static std::once_flag g_worker_once;
static std::thread g_worker;
static std::mutex g_mutex;
static std::condition_variable g_cv_task;
static std::condition_variable g_cv_done;
static std::function<void()> g_pending_task;
static bool g_quit = false;

static void MtaWorkerThread() {
  BT_VERBOSE("MtaWorkerThread: starting");
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
  } catch (const std::exception& e) {
    BT_LOG("MtaWorkerThread ERROR: " << e.what());
  } catch (...) {
    BT_LOG("MtaWorkerThread ERROR: init_apartment failed");
  }
  std::unique_lock<std::mutex> lock(g_mutex);
  for (;;) {
    g_cv_task.wait(lock, [] { return g_pending_task != nullptr || g_quit; });
    if (g_quit) break;
    std::function<void()> task = std::move(g_pending_task);
    g_pending_task = nullptr;
    lock.unlock();
    try {
      task();
    } catch (const std::exception& e) {
      BT_LOG("MtaWorkerThread ERROR: " << e.what());
    } catch (...) {
      BT_LOG("MtaWorkerThread ERROR: task threw unknown");
    }
    lock.lock();
    g_cv_done.notify_one();
  }
}

/// Run WinRT work on a dedicated MTA thread. Blocking .get() on IAsyncOperation
/// is not allowed on STA; running on MTA avoids the !is_sta_thread() assertion.
static void RunOnMta(std::function<void()> f) {
  std::call_once(g_worker_once, []() {
    g_worker = std::thread(MtaWorkerThread);
    g_worker.detach();
  });
  std::unique_lock<std::mutex> lock(g_mutex);
  g_pending_task = std::move(f);
  g_cv_task.notify_one();
  g_cv_done.wait(lock, [] { return g_pending_task == nullptr; });
}

void BluetoothWinRtInit() {}

static std::string HStringToUtf8(const winrt::hstring& hs) {
  if (hs.empty()) return "";
  try {
    std::wstring ws(hs.c_str());
    if (ws.empty()) return "";
    int size = WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), nullptr, 0, nullptr, nullptr);
    if (size <= 0) return "";
    std::string s(size, 0);
    int written = WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), &s[0], size, nullptr, nullptr);
    if (written <= 0) return "";
    return s;
  } catch (...) {
    return "";
  }
}

static std::vector<SppDeviceInfo> BluetoothFindAllSppDevicesImpl() {
  std::vector<SppDeviceInfo> out;
  try {
    auto selector = winrt_win::Devices::Bluetooth::Rfcomm::RfcommDeviceService::GetDeviceSelector(
        winrt_win::Devices::Bluetooth::Rfcomm::RfcommServiceId::SerialPort());
    auto async_find = winrt_win::Devices::Enumeration::DeviceInformation::FindAllAsync(selector);
    auto collection = async_find.get();
    uint32_t count = collection.Size();
    for (uint32_t i = 0; i < count; i++) {
      try {
        auto di = collection.GetAt(i);
        SppDeviceInfo info;
        info.id = HStringToUtf8(di.Id());
        // di.Name(), Properties(), Pairing() cause crashes on some devices; use defaults.
        info.name = "Bluetooth Printer";
        info.signal_strength = -50;
        info.is_paired = false;
        info.mac_address = info.id;
        info.is_connected = (g_sockets.find(info.id) != g_sockets.end());
        out.push_back(std::move(info));
      } catch (const std::exception& e) {
        BT_LOG("FindAllSppDevicesImpl: skip device " << i << ": " << e.what());
      } catch (...) {
        BT_LOG("FindAllSppDevicesImpl: skip device " << i << " (unknown)");
      }
    }
  } catch (const std::exception& e) {
    BT_LOG("FindAllSppDevicesImpl ERROR: " << e.what());
  } catch (...) {
    BT_LOG("FindAllSppDevicesImpl ERROR: unknown");
  }
  return out;
}

std::vector<SppDeviceInfo> BluetoothFindAllSppDevices() {
  std::vector<SppDeviceInfo> result;
  RunOnMta([&result]() { result = BluetoothFindAllSppDevicesImpl(); });
  return result;
}

/// Post task to worker; callback runs on worker thread when scan completes.
static void RunOnMtaAsync(std::function<void()> f) {
  std::call_once(g_worker_once, []() {
    g_worker = std::thread(MtaWorkerThread);
    g_worker.detach();
  });
  std::lock_guard<std::mutex> lock(g_mutex);
  g_pending_task = std::move(f);
  g_cv_task.notify_one();
}

void BluetoothFindAllSppDevicesAsync(std::function<void(std::vector<SppDeviceInfo>)> callback) {
  RunOnMtaAsync([callback]() {
    std::vector<SppDeviceInfo> result = BluetoothFindAllSppDevicesImpl();
    try {
      callback(std::move(result));
    } catch (const std::exception& e) {
      BT_LOG("BluetoothFindAllSppDevicesAsync ERROR: " << e.what());
    } catch (...) {
      BT_LOG("BluetoothFindAllSppDevicesAsync ERROR: callback threw unknown");
    }
  });
}

/// For pairing, use device-level ID; RFCOMM service ID may crash CreateFromIdAsync.
static std::string GetDeviceIdForPairing(const std::string& rfcomm_or_device_id) {
  size_t pos = rfcomm_or_device_id.find("#RFCOMM");
  if (pos != std::string::npos) {
    return rfcomm_or_device_id.substr(0, pos);
  }
  return rfcomm_or_device_id;
}

static bool BluetoothPairDeviceImpl(const std::string& device_id) {
  std::string id_for_pairing = GetDeviceIdForPairing(device_id);
  try {
    winrt::hstring id(winrt::to_hstring(id_for_pairing));
    auto async_di = winrt_win::Devices::Enumeration::DeviceInformation::CreateFromIdAsync(id);
    auto di = async_di.get();
    auto pairing = di.Pairing();
    auto pair_op = pairing.PairAsync();
    auto pair_result = pair_op.get();
    bool ok = (pair_result.Status() == winrt_win::Devices::Enumeration::DevicePairingResultStatus::Paired ||
               pair_result.Status() == winrt_win::Devices::Enumeration::DevicePairingResultStatus::AlreadyPaired);
    return ok;
  } catch (const std::exception& e) {
    BT_LOG("PairImpl ERROR: " << e.what());
    return false;
  } catch (...) {
    BT_LOG("PairImpl ERROR: unknown");
    return false;
  }
}

bool BluetoothPairDevice(const std::string& device_id) {
  bool result = false;
  RunOnMta([&]() { result = BluetoothPairDeviceImpl(device_id); });
  return result;
}

void BluetoothPairDeviceAsync(const std::string& device_id,
                              std::function<void(bool)> callback) {
  RunOnMtaAsync([device_id, callback]() {
    bool paired = BluetoothPairDeviceImpl(device_id);
    try {
      callback(paired);
    } catch (const std::exception& e) {
      BT_LOG("BluetoothPairDeviceAsync ERROR: " << e.what());
    } catch (...) {
      BT_LOG("BluetoothPairDeviceAsync ERROR: callback threw");
    }
  });
}

/// Non-blocking pairing from STA (platform) thread. Uses Completed handlers so no .get().
/// Allows Windows pairing UI to appear when needed.
void BluetoothPairDeviceAsyncSta(const std::string& device_id,
                                 std::function<void(bool)> callback) {
  std::string id_for_pairing = GetDeviceIdForPairing(device_id);
  try {
    winrt::hstring id(winrt::to_hstring(id_for_pairing));
    auto async_di = winrt_win::Devices::Enumeration::DeviceInformation::CreateFromIdAsync(id);
    using AsyncStatus = winrt_win::Foundation::AsyncStatus;
    async_di.Completed([callback](auto const& op, AsyncStatus status) {
      try {
        if (status != AsyncStatus::Completed) {
          BT_LOG("PairDeviceAsyncSta ERROR: CreateFromIdAsync status=" << (int)status);
          callback(false);
          return;
        }
        auto di = op.GetResults();
        auto pair_op = di.Pairing().PairAsync();
        pair_op.Completed([callback](auto const& op2, AsyncStatus status2) {
          try {
            if (status2 != AsyncStatus::Completed) {
              BT_LOG("PairDeviceAsyncSta ERROR: PairAsync status=" << (int)status2);
              callback(false);
              return;
            }
            auto pair_result = op2.GetResults();
            using Status = winrt_win::Devices::Enumeration::DevicePairingResultStatus;
            bool ok = (pair_result.Status() == Status::Paired ||
                       pair_result.Status() == Status::AlreadyPaired);
            callback(ok);
          } catch (const std::exception& e) {
            BT_LOG("PairDeviceAsyncSta ERROR: " << e.what());
            callback(false);
          } catch (...) {
            BT_LOG("PairDeviceAsyncSta ERROR: unknown");
            callback(false);
          }
        });
      } catch (const std::exception& e) {
        BT_LOG("PairDeviceAsyncSta ERROR: " << e.what());
        callback(false);
      } catch (...) {
        BT_LOG("PairDeviceAsyncSta ERROR: unknown");
        callback(false);
      }
    });
  } catch (const std::exception& e) {
    BT_LOG("PairDeviceAsyncSta ERROR: " << e.what());
    callback(false);
  } catch (...) {
    BT_LOG("PairDeviceAsyncSta ERROR: unknown");
    callback(false);
  }
}

static void BluetoothDisconnectImpl(const std::string& device_id) {
  g_writers.erase(device_id);
  auto it = g_sockets.find(device_id);
  if (it != g_sockets.end()) {
    try { it->second.Close(); } catch (...) {}
    g_sockets.erase(it);
  }
}

static bool BluetoothUnpairDeviceImpl(const std::string& device_id) {
  try {
    BluetoothDisconnectImpl(device_id);
    std::string id_for_pairing = GetDeviceIdForPairing(device_id);
    winrt::hstring id(winrt::to_hstring(id_for_pairing));
    auto async_di = winrt_win::Devices::Enumeration::DeviceInformation::CreateFromIdAsync(id);
    auto di = async_di.get();
    auto pairing = di.Pairing();
    pairing.UnpairAsync().get();
    return true;
  } catch (...) {
    return false;
  }
}

bool BluetoothUnpairDevice(const std::string& device_id) {
  bool result = false;
  RunOnMta([&]() { result = BluetoothUnpairDeviceImpl(device_id); });
  return result;
}

void BluetoothUnpairDeviceAsync(const std::string& device_id,
                                std::function<void(bool)> callback) {
  RunOnMtaAsync([device_id, callback]() {
    bool ok = BluetoothUnpairDeviceImpl(device_id);
    try {
      callback(ok);
    } catch (const std::exception& e) {
      BT_LOG("BluetoothUnpairDeviceAsync ERROR: " << e.what());
    } catch (...) {
      BT_LOG("BluetoothUnpairDeviceAsync ERROR: callback threw");
    }
  });
}

static bool BluetoothConnectImpl(const std::string& device_id) {
  BluetoothDisconnectImpl(device_id);
  try {
    winrt::hstring id(winrt::to_hstring(device_id));
    auto async_svc = winrt_win::Devices::Bluetooth::Rfcomm::RfcommDeviceService::FromIdAsync(id);
    auto service = async_svc.get();
    if (!service) {
      BT_LOG("ConnectImpl ERROR: FromIdAsync returned null");
      return false;
    }
    winrt_win::Networking::Sockets::StreamSocket socket;
    socket.ConnectAsync(
        service.ConnectionHostName(),
        service.ConnectionServiceName(),
        winrt_win::Networking::Sockets::SocketProtectionLevel::BluetoothEncryptionAllowNullAuthentication
    ).get();
    g_sockets[device_id] = std::move(socket);
    g_writers[device_id] = winrt_win::Storage::Streams::DataWriter(
        g_sockets[device_id].OutputStream());
    return true;
  } catch (const std::exception& e) {
    BT_LOG("ConnectImpl ERROR: " << e.what());
    return false;
  } catch (...) {
    BT_LOG("ConnectImpl ERROR: unknown");
    return false;
  }
}

bool BluetoothConnect(const std::string& device_id) {
  bool result = false;
  RunOnMta([&]() { result = BluetoothConnectImpl(device_id); });
  return result;
}

void BluetoothConnectAsync(const std::string& device_id,
                           std::function<void(bool)> callback) {
  RunOnMtaAsync([device_id, callback]() {
    bool connected = BluetoothConnectImpl(device_id);
    try {
      callback(connected);
    } catch (const std::exception& e) {
      BT_LOG("BluetoothConnectAsync ERROR: " << e.what());
    } catch (...) {
      BT_LOG("BluetoothConnectAsync ERROR: callback threw");
    }
  });
}

void BluetoothDisconnect(const std::string& device_id) {
  RunOnMta([device_id]() { BluetoothDisconnectImpl(device_id); });
}

bool BluetoothIsConnected(const std::string& device_id) {
  bool result = false;
  RunOnMta([&]() { result = (g_sockets.find(device_id) != g_sockets.end()); });
  return result;
}

static bool BluetoothSendImpl(const std::string& device_id, const uint8_t* data, size_t size) {
  auto it = g_sockets.find(device_id);
  if (it == g_sockets.end()) {
    BT_LOG("BluetoothSendImpl ERROR: socket not found");
    return false;
  }
  if (size == 0) return true;
  auto wit = g_writers.find(device_id);
  if (wit == g_writers.end()) {
    BT_LOG("BluetoothSendImpl ERROR: no DataWriter");
    return false;
  }
  try {
    std::vector<uint8_t> vec(data, data + size);
    wit->second.WriteBytes(winrt::array_view<uint8_t>(vec));
    wit->second.StoreAsync().get();
    wit->second.FlushAsync().get();
    return true;
  } catch (const winrt::hresult_error& e) {
    BT_LOG("BluetoothSendImpl ERROR: 0x" << std::hex << e.code() << " " << HStringToUtf8(e.message()));
    return false;
  } catch (const std::exception& e) {
    BT_LOG("BluetoothSendImpl ERROR: " << e.what());
    return false;
  } catch (...) {
    BT_LOG("BluetoothSendImpl ERROR: unknown");
    return false;
  }
}

bool BluetoothSend(const std::string& device_id, const uint8_t* data, size_t size) {
  std::vector<uint8_t> copy(data, data + size);
  bool result = false;
  RunOnMta([&]() { result = BluetoothSendImpl(device_id, copy.data(), copy.size()); });
  return result;
}

void BluetoothSendAsync(const std::string& device_id,
                        const uint8_t* data,
                        size_t size,
                        std::function<void(bool)> callback) {
  std::vector<uint8_t> copy(data, data + size);
  RunOnMtaAsync([device_id, copy, callback]() {
    bool ok = BluetoothSendImpl(device_id, copy.data(), copy.size());
    try {
      callback(ok);
    } catch (const std::exception& e) {
      BT_LOG("BluetoothSendAsync ERROR: " << e.what());
    } catch (...) {
      BT_LOG("BluetoothSendAsync ERROR: callback threw");
    }
  });
}

}  // namespace flutter_thermal_printer_windows
