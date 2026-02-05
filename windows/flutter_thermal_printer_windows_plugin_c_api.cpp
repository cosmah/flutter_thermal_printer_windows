#include "include/flutter_thermal_printer_windows/flutter_thermal_printer_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_thermal_printer_windows_plugin.h"

void FlutterThermalPrinterWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_thermal_printer_windows::FlutterThermalPrinterWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
