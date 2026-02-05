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

static std::unordered_map<std::string, winrt_win::Networking::Sockets::StreamSocket> g_sockets;
static std::once_flag g_worker_once;
static std::thread g_worker;
static std::mutex g_mutex;
static std::condition_variable g_cv_task;
static std::condition_variable g_cv_done;
static std::function<void()> g_pending_task;
static bool g_quit = false;

static void MtaWorkerThread() {
  BT_LOG("MtaWorkerThread: starting, calling init_apartment(MTA)");
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    BT_LOG("MtaWorkerThread: init_apartment done");
  } catch (const std::exception& e) {
    BT_LOG(std::string("MtaWorkerThread: init_apartment exception: ") + e.what());
  } catch (...) {
    BT_LOG("MtaWorkerThread: init_apartment unknown exception");
  }
  std::unique_lock<std::mutex> lock(g_mutex);
  for (;;) {
    g_cv_task.wait(lock, [] { return g_pending_task != nullptr || g_quit; });
    if (g_quit) break;
    std::function<void()> task = std::move(g_pending_task);
    g_pending_task = nullptr;
    lock.unlock();
    BT_LOG("MtaWorkerThread: running task");
    try {
      task();
      BT_LOG("MtaWorkerThread: task completed");
    } catch (const std::exception& e) {
      BT_LOG(std::string("MtaWorkerThread: task threw: ") + e.what());
    } catch (...) {
      BT_LOG("MtaWorkerThread: task threw unknown exception");
    }
    lock.lock();
    g_cv_done.notify_one();
  }
  BT_LOG("MtaWorkerThread: exiting");
}

/// Run WinRT work on a dedicated MTA thread. Blocking .get() on IAsyncOperation
/// is not allowed on STA; running on MTA avoids the !is_sta_thread() assertion.
static void RunOnMta(std::function<void()> f) {
  BT_LOG("RunOnMta: enter");
  std::call_once(g_worker_once, []() {
    BT_LOG("RunOnMta: starting worker thread");
    g_worker = std::thread(MtaWorkerThread);
    g_worker.detach();
    BT_LOG("RunOnMta: worker started");
  });
  BT_LOG("RunOnMta: posting task, waiting");
  std::unique_lock<std::mutex> lock(g_mutex);
  g_pending_task = std::move(f);
  g_cv_task.notify_one();
  g_cv_done.wait(lock, [] { return g_pending_task == nullptr; });
  BT_LOG("RunOnMta: task done, exit");
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
  BT_LOG("FindAllSppDevicesImpl: enter");
  try {
    BT_LOG("FindAllSppDevicesImpl: getting selector");
    auto selector = winrt_win::Devices::Bluetooth::Rfcomm::RfcommDeviceService::GetDeviceSelector(
        winrt_win::Devices::Bluetooth::Rfcomm::RfcommServiceId::SerialPort());
    BT_LOG("FindAllSppDevicesImpl: calling FindAllAsync");
    auto async_find = winrt_win::Devices::Enumeration::DeviceInformation::FindAllAsync(selector);
    BT_LOG("FindAllSppDevicesImpl: calling .get()");
    auto collection = async_find.get();
    uint32_t count = collection.Size();
    BT_LOG("FindAllSppDevicesImpl: got " << count << " devices");
    for (uint32_t i = 0; i < count; i++) {
      try {
        BT_LOG("FindAllSppDevicesImpl: processing device " << (i + 1) << "/" << count);
        auto di = collection.GetAt(i);
        SppDeviceInfo info;
        info.id = HStringToUtf8(di.Id());
        BT_LOG("FindAllSppDevicesImpl: device " << i << " id=" << info.id);
        // di.Name(), Properties(), Pairing() cause crashes on some devices; use defaults.
        info.name = "Bluetooth Printer";
        info.signal_strength = -50;
        info.is_paired = false;
        info.mac_address = info.id;
        info.is_connected = (g_sockets.find(info.id) != g_sockets.end());
        BT_LOG("FindAllSppDevicesImpl: device " << i << " ok, name=" << info.name << ", pushing");
        out.push_back(std::move(info));
      } catch (const std::exception& e) {
        BT_LOG("FindAllSppDevicesImpl: device " << i << " SKIP exception: " << e.what());
      } catch (...) {
        BT_LOG("FindAllSppDevicesImpl: device " << i << " SKIP unknown exception");
      }
    }
    BT_LOG("FindAllSppDevicesImpl: done, " << out.size() << " devices collected");
  } catch (const std::exception& e) {
    BT_LOG("FindAllSppDevicesImpl: FATAL exception: " << e.what());
  } catch (...) {
    BT_LOG("FindAllSppDevicesImpl: FATAL unknown exception");
  }
  return out;
}

std::vector<SppDeviceInfo> BluetoothFindAllSppDevices() {
  BT_LOG("BluetoothFindAllSppDevices: enter");
  std::vector<SppDeviceInfo> result;
  RunOnMta([&result]() { result = BluetoothFindAllSppDevicesImpl(); });
  BT_LOG("BluetoothFindAllSppDevices: got " << result.size() << " devices");
  return result;
}

/// Post task to worker; callback runs on worker thread when scan completes.
static void RunOnMtaAsync(std::function<void()> f) {
  BT_LOG("RunOnMtaAsync: posting task (fire-and-forget)");
  std::call_once(g_worker_once, []() {
    BT_LOG("RunOnMtaAsync: starting worker thread");
    g_worker = std::thread(MtaWorkerThread);
    g_worker.detach();
  });
  std::lock_guard<std::mutex> lock(g_mutex);
  g_pending_task = std::move(f);
  g_cv_task.notify_one();
}

void BluetoothFindAllSppDevicesAsync(std::function<void(std::vector<SppDeviceInfo>)> callback) {
  BT_LOG("BluetoothFindAllSppDevicesAsync: enter");
  RunOnMtaAsync([callback]() {
    BT_LOG("BluetoothFindAllSppDevicesAsync: worker running scan");
    std::vector<SppDeviceInfo> result = BluetoothFindAllSppDevicesImpl();
    BT_LOG("BluetoothFindAllSppDevicesAsync: scan done, invoking callback with " << result.size() << " devices");
    try {
      callback(std::move(result));
    } catch (const std::exception& e) {
      BT_LOG("BluetoothFindAllSppDevicesAsync: callback threw: " << e.what());
    } catch (...) {
      BT_LOG("BluetoothFindAllSppDevicesAsync: callback threw unknown");
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
  BT_LOG("PairImpl: device_id=" << device_id.substr(0, 60) << "... id_for_pairing=" << id_for_pairing.substr(0, 60) << "...");
  try {
    BT_LOG("PairImpl: 1 creating hstring");
    winrt::hstring id(winrt::to_hstring(id_for_pairing));
    BT_LOG("PairImpl: 2 calling CreateFromIdAsync");
    auto async_di = winrt_win::Devices::Enumeration::DeviceInformation::CreateFromIdAsync(id);
    BT_LOG("PairImpl: 3 calling .get()");
    auto di = async_di.get();
    BT_LOG("PairImpl: 4 got DeviceInformation");
    auto pairing = di.Pairing();
    BT_LOG("PairImpl: 5 got Pairing");
    // Always call PairAsync: IsPaired() can be stale/wrong for device-level ID.
    // If already paired, PairAsync returns AlreadyPaired.
    BT_LOG("PairImpl: 6 calling PairAsync");
    auto pair_op = pairing.PairAsync();
    BT_LOG("PairImpl: 7 calling pair_op.get()");
    auto pair_result = pair_op.get();
    BT_LOG("PairImpl: 8 got result");
    bool ok = (pair_result.Status() == winrt_win::Devices::Enumeration::DevicePairingResultStatus::Paired ||
               pair_result.Status() == winrt_win::Devices::Enumeration::DevicePairingResultStatus::AlreadyPaired);
    BT_LOG("PairImpl: 9 status=" << (int)pair_result.Status() << " ok=" << ok);
    return ok;
  } catch (const std::exception& e) {
    BT_LOG("PairImpl: exception " << e.what());
    return false;
  } catch (...) {
    BT_LOG("PairImpl: unknown exception");
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
  BT_LOG("BluetoothPairDeviceAsync: enter (MTA required: .get() asserts !is_sta_thread)");
  RunOnMtaAsync([device_id, callback]() {
    BT_LOG("BluetoothPairDeviceAsync: worker running pair");
    bool paired = BluetoothPairDeviceImpl(device_id);
    BT_LOG("BluetoothPairDeviceAsync: pair done, paired=" << paired);
    try {
      callback(paired);
    } catch (const std::exception& e) {
      BT_LOG("BluetoothPairDeviceAsync: callback threw: " << e.what());
    } catch (...) {
      BT_LOG("BluetoothPairDeviceAsync: callback threw unknown");
    }
  });
}

/// Non-blocking pairing from STA (platform) thread. Uses Completed handlers so no .get().
/// Allows Windows pairing UI to appear when needed.
void BluetoothPairDeviceAsyncSta(const std::string& device_id,
                                 std::function<void(bool)> callback) {
  std::string id_for_pairing = GetDeviceIdForPairing(device_id);
  BT_LOG("BluetoothPairDeviceAsyncSta: enter, id_for_pairing=" << id_for_pairing.substr(0, 50) << "...");
  try {
    winrt::hstring id(winrt::to_hstring(id_for_pairing));
    auto async_di = winrt_win::Devices::Enumeration::DeviceInformation::CreateFromIdAsync(id);
    using AsyncStatus = winrt_win::Foundation::AsyncStatus;
    async_di.Completed([callback](auto const& op, AsyncStatus status) {
      try {
        if (status != AsyncStatus::Completed) {
          BT_LOG("BluetoothPairDeviceAsyncSta: CreateFromIdAsync status=" << (int)status);
          callback(false);
          return;
        }
        auto di = op.GetResults();
        auto pair_op = di.Pairing().PairAsync();
        pair_op.Completed([callback](auto const& op2, AsyncStatus status2) {
          try {
            if (status2 != AsyncStatus::Completed) {
              BT_LOG("BluetoothPairDeviceAsyncSta: PairAsync status=" << (int)status2);
              callback(false);
              return;
            }
            auto pair_result = op2.GetResults();
            using Status = winrt_win::Devices::Enumeration::DevicePairingResultStatus;
            bool ok = (pair_result.Status() == Status::Paired ||
                       pair_result.Status() == Status::AlreadyPaired);
            BT_LOG("BluetoothPairDeviceAsyncSta: pair done status=" << (int)pair_result.Status() << " ok=" << ok);
            callback(ok);
          } catch (const std::exception& e) {
            BT_LOG("BluetoothPairDeviceAsyncSta: PairAsync Completed exception: " << e.what());
            callback(false);
          } catch (...) {
            BT_LOG("BluetoothPairDeviceAsyncSta: PairAsync Completed unknown exception");
            callback(false);
          }
        });
      } catch (const std::exception& e) {
        BT_LOG("BluetoothPairDeviceAsyncSta: CreateFromIdAsync Completed exception: " << e.what());
        callback(false);
      } catch (...) {
        BT_LOG("BluetoothPairDeviceAsyncSta: CreateFromIdAsync Completed unknown exception");
        callback(false);
      }
    });
  } catch (const std::exception& e) {
    BT_LOG("BluetoothPairDeviceAsyncSta: exception: " << e.what());
    callback(false);
  } catch (...) {
    BT_LOG("BluetoothPairDeviceAsyncSta: unknown exception");
    callback(false);
  }
}

static void BluetoothDisconnectImpl(const std::string& device_id) {
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
  BT_LOG("BluetoothUnpairDeviceAsync: enter");
  RunOnMtaAsync([device_id, callback]() {
    BT_LOG("BluetoothUnpairDeviceAsync: worker running unpair");
    bool ok = BluetoothUnpairDeviceImpl(device_id);
    BT_LOG("BluetoothUnpairDeviceAsync: unpair done, ok=" << ok);
    try {
      callback(ok);
    } catch (const std::exception& e) {
      BT_LOG("BluetoothUnpairDeviceAsync: callback threw: " << e.what());
    } catch (...) {
      BT_LOG("BluetoothUnpairDeviceAsync: callback threw unknown");
    }
  });
}

static bool BluetoothConnectImpl(const std::string& device_id) {
  BluetoothDisconnectImpl(device_id);
  try {
    winrt::hstring id(winrt::to_hstring(device_id));
    auto async_svc = winrt_win::Devices::Bluetooth::Rfcomm::RfcommDeviceService::FromIdAsync(id);
    auto service = async_svc.get();
    if (!service) return false;
    winrt_win::Networking::Sockets::StreamSocket socket;
    socket.ConnectAsync(
        service.ConnectionHostName(),
        service.ConnectionServiceName(),
        winrt_win::Networking::Sockets::SocketProtectionLevel::BluetoothEncryptionAllowNullAuthentication
    ).get();
    g_sockets[device_id] = std::move(socket);
    return true;
  } catch (...) {
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
  BT_LOG("BluetoothConnectAsync: enter");
  RunOnMtaAsync([device_id, callback]() {
    BT_LOG("BluetoothConnectAsync: worker running connect");
    bool connected = BluetoothConnectImpl(device_id);
    BT_LOG("BluetoothConnectAsync: connect done, connected=" << connected);
    try {
      callback(connected);
    } catch (const std::exception& e) {
      BT_LOG("BluetoothConnectAsync: callback threw: " << e.what());
    } catch (...) {
      BT_LOG("BluetoothConnectAsync: callback threw unknown");
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
  if (it == g_sockets.end()) return false;
  if (size == 0) return true;
  try {
    auto out_stream = it->second.OutputStream();
    winrt_win::Storage::Streams::DataWriter writer(out_stream);
    std::vector<uint8_t> vec(data, data + size);
    writer.WriteBytes(winrt::array_view<uint8_t>(vec));
    writer.StoreAsync().get();
    writer.FlushAsync().get();
    return true;
  } catch (...) {
    return false;
  }
}

bool BluetoothSend(const std::string& device_id, const uint8_t* data, size_t size) {
  std::vector<uint8_t> copy(data, data + size);
  bool result = false;
  RunOnMta([&]() { result = BluetoothSendImpl(device_id, copy.data(), copy.size()); });
  return result;
}

}  // namespace flutter_thermal_printer_windows
