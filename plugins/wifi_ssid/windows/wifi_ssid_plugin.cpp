#include "wifi_ssid_plugin.h"

#include <windows.h>
#include <wlanapi.h>
#include <objbase.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#pragma comment(lib, "ole32.lib")

namespace wifi_ssid {

namespace {

using WlanOpenHandleFunction = decltype(&WlanOpenHandle);
using WlanEnumInterfacesFunction = decltype(&WlanEnumInterfaces);
using WlanQueryInterfaceFunction = decltype(&WlanQueryInterface);
using WlanFreeMemoryFunction = decltype(&WlanFreeMemory);
using WlanCloseHandleFunction = decltype(&WlanCloseHandle);

class WlanApi {
 public:
  WlanApi() : module_(LoadLibraryW(L"wlanapi.dll")) {
    if (module_ == nullptr) {
      return;
    }

    open_handle = reinterpret_cast<WlanOpenHandleFunction>(
        GetProcAddress(module_, "WlanOpenHandle"));
    enum_interfaces = reinterpret_cast<WlanEnumInterfacesFunction>(
        GetProcAddress(module_, "WlanEnumInterfaces"));
    query_interface = reinterpret_cast<WlanQueryInterfaceFunction>(
        GetProcAddress(module_, "WlanQueryInterface"));
    free_memory = reinterpret_cast<WlanFreeMemoryFunction>(
        GetProcAddress(module_, "WlanFreeMemory"));
    close_handle = reinterpret_cast<WlanCloseHandleFunction>(
        GetProcAddress(module_, "WlanCloseHandle"));

    if (!IsAvailable()) {
      FreeLibrary(module_);
      module_ = nullptr;
      open_handle = nullptr;
      enum_interfaces = nullptr;
      query_interface = nullptr;
      free_memory = nullptr;
      close_handle = nullptr;
    }
  }

  ~WlanApi() {
    if (module_ != nullptr) {
      FreeLibrary(module_);
    }
  }

  WlanApi(const WlanApi &) = delete;
  WlanApi &operator=(const WlanApi &) = delete;

  bool IsAvailable() const {
    return module_ != nullptr && open_handle != nullptr &&
           enum_interfaces != nullptr && query_interface != nullptr &&
           free_memory != nullptr && close_handle != nullptr;
  }

  WlanOpenHandleFunction open_handle = nullptr;
  WlanEnumInterfacesFunction enum_interfaces = nullptr;
  WlanQueryInterfaceFunction query_interface = nullptr;
  WlanFreeMemoryFunction free_memory = nullptr;
  WlanCloseHandleFunction close_handle = nullptr;

 private:
  HMODULE module_ = nullptr;
};

std::unique_ptr<
    flutter::MethodChannel<flutter::EncodableValue>,
    std::default_delete<flutter::MethodChannel<flutter::EncodableValue>>>
    channel = nullptr;

constexpr int kPermissionGranted = 0;
constexpr int kPermissionDenied = 1;

}  // namespace

void WifiSsidPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "wifi_ssid",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WifiSsidPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WifiSsidPlugin::WifiSsidPlugin() {}

WifiSsidPlugin::~WifiSsidPlugin() {}

void WifiSsidPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getSsid") == 0) {
    GetSsid(std::move(result));
  } else if (method_call.method_name().compare("checkPermission") == 0 ||
             method_call.method_name().compare("requestPermission") == 0) {
    CheckPermission(std::move(result));
  } else {
    result->NotImplemented();
  }
}

void WifiSsidPlugin::CheckPermission(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  WlanApi wlan_api;
  if (!wlan_api.IsAvailable()) {
    result->Success(flutter::EncodableValue(kPermissionGranted));
    return;
  }

  HANDLE client_handle = nullptr;
  DWORD current_version = 0;
  DWORD result_code = wlan_api.open_handle(
      2, nullptr, &current_version, &client_handle);
  if (result_code == ERROR_ACCESS_DENIED) {
    result->Success(flutter::EncodableValue(kPermissionDenied));
    return;
  }
  if (result_code != ERROR_SUCCESS) {
    result->Success(flutter::EncodableValue(kPermissionGranted));
    return;
  }

  PWLAN_INTERFACE_INFO_LIST interfaces = nullptr;
  result_code = wlan_api.enum_interfaces(client_handle, nullptr, &interfaces);
  if (result_code == ERROR_ACCESS_DENIED) {
    wlan_api.close_handle(client_handle, nullptr);
    result->Success(flutter::EncodableValue(kPermissionDenied));
    return;
  }
  if (result_code != ERROR_SUCCESS || interfaces == nullptr) {
    wlan_api.close_handle(client_handle, nullptr);
    result->Success(flutter::EncodableValue(kPermissionGranted));
    return;
  }

  for (DWORD index = 0; index < interfaces->dwNumberOfItems; index++) {
    PWLAN_CONNECTION_ATTRIBUTES connection = nullptr;
    DWORD data_size = sizeof(WLAN_CONNECTION_ATTRIBUTES);
    result_code = wlan_api.query_interface(
        client_handle, &interfaces->InterfaceInfo[index].InterfaceGuid,
        wlan_intf_opcode_current_connection, nullptr, &data_size,
        reinterpret_cast<PVOID*>(&connection), nullptr);
    if (connection != nullptr) {
      wlan_api.free_memory(connection);
    }
    if (result_code == ERROR_ACCESS_DENIED) {
      wlan_api.free_memory(interfaces);
      wlan_api.close_handle(client_handle, nullptr);
      result->Success(flutter::EncodableValue(kPermissionDenied));
      return;
    }
  }

  wlan_api.free_memory(interfaces);
  wlan_api.close_handle(client_handle, nullptr);
  result->Success(flutter::EncodableValue(kPermissionGranted));
}

void WifiSsidPlugin::GetSsid(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Windows Server installations may omit the WLAN feature and its optional
  // wlanapi.dll module. SSID detection is best-effort and must not prevent
  // the main application from starting in that environment.
  WlanApi wlan_api;
  if (!wlan_api.IsAvailable()) {
    result->Success(flutter::EncodableValue());
    return;
  }

  HANDLE hClient = nullptr;
  DWORD dwMaxClient = 2;
  DWORD dwCurVersion = 0;
  DWORD dwResult = wlan_api.open_handle(dwMaxClient, nullptr, &dwCurVersion,
                                        &hClient);
  if (dwResult == ERROR_ACCESS_DENIED) {
    result->Success(flutter::EncodableValue());
    return;
  }
  if (dwResult != ERROR_SUCCESS) {
    result->Error("WLAN_ERROR", "Failed to open WLAN handle",
                  flutter::EncodableValue(static_cast<int>(dwResult)));
    return;
  }

  PWLAN_INTERFACE_INFO_LIST pIfList = nullptr;
  dwResult = wlan_api.enum_interfaces(hClient, nullptr, &pIfList);
  if (dwResult == ERROR_ACCESS_DENIED) {
    wlan_api.close_handle(hClient, nullptr);
    result->Success(flutter::EncodableValue());
    return;
  }
  if (dwResult != ERROR_SUCCESS) {
    wlan_api.close_handle(hClient, nullptr);
    result->Error("WLAN_ERROR", "Failed to enumerate WLAN interfaces",
                  flutter::EncodableValue(static_cast<int>(dwResult)));
    return;
  }

  std::string ssid;
  DWORD query_error = ERROR_SUCCESS;
  for (DWORD i = 0; i < pIfList->dwNumberOfItems; i++) {
    PWLAN_CONNECTION_ATTRIBUTES pConnAttrib = nullptr;
    DWORD dwDataSize = sizeof(WLAN_CONNECTION_ATTRIBUTES);
    WLAN_INTF_OPCODE opCode = wlan_intf_opcode_current_connection;

    dwResult = wlan_api.query_interface(
        hClient, &pIfList->InterfaceInfo[i].InterfaceGuid, opCode, nullptr,
        &dwDataSize, (PVOID *)&pConnAttrib, nullptr);

    if (dwResult == ERROR_SUCCESS && pConnAttrib != nullptr) {
      if (pConnAttrib->isState == wlan_interface_state_connected) {
        DWORD ssidLen =
            pConnAttrib->wlanAssociationAttributes.dot11Ssid.uSSIDLength;
        if (ssidLen > 0 && ssidLen <= 32) {
          ssid.assign(
              reinterpret_cast<const char *>(
                  pConnAttrib->wlanAssociationAttributes.dot11Ssid.ucSSID),
              ssidLen);
        }
        wlan_api.free_memory(pConnAttrib);
        break;
      }
      wlan_api.free_memory(pConnAttrib);
    } else if (dwResult == ERROR_ACCESS_DENIED) {
      query_error = dwResult;
      break;
    } else if (query_error == ERROR_SUCCESS) {
      query_error = dwResult;
    }
  }

  wlan_api.free_memory(pIfList);
  wlan_api.close_handle(hClient, nullptr);

  if (query_error == ERROR_ACCESS_DENIED || ssid.empty()) {
    result->Success(flutter::EncodableValue());
    return;
  }

  result->Success(flutter::EncodableValue(ssid));
}

}  // namespace wifi_ssid
