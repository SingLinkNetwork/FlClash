// These APIs require Vista-era networking definitions and Winsock types.
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif
#ifndef NTDDI_VERSION
#define NTDDI_VERSION 0x06000000
#endif
#include <winsock2.h>
#include <windows.h>

#include "proxy_plugin.h"

#include <WinInet.h>
#include <Ras.h>
#include <RasError.h>
#include <iphlpapi.h>
#include <netioapi.h>
#include <string>
#include <vector>

#pragma comment(lib, "wininet")
#pragma comment(lib, "Rasapi32")
#pragma comment(lib, "iphlpapi")

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>

namespace
{

std::wstring Utf8ToWide(const std::string& value)
{
  if (value.empty())
  {
    return {};
  }
  const int size = MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0);
  if (size <= 0)
  {
    return std::wstring(value.begin(), value.end());
  }
  std::wstring result(size, L'\0');
  MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
      result.data(), size);
  return result;
}

std::wstring BuildBypassList(const flutter::EncodableList& bypassDomain)
{
  std::wstring bypassList;
  for (const auto& domain : bypassDomain) {
    const auto* value = std::get_if<std::string>(&domain);
    if (value == nullptr)
    {
      continue;
    }
    if (!bypassList.empty()) {
       bypassList += L";";
    }
    bypassList += Utf8ToWide(*value);
  }
  return bypassList;
}

bool SetOptionsForConnection(
    INTERNET_PER_CONN_OPTION_LIST& list,
    LPTSTR connection)
{
  list.pszConnection = connection;
  return InternetSetOption(
      nullptr,
      INTERNET_OPTION_PER_CONNECTION_OPTION,
      &list,
      sizeof(list)) != FALSE;
}

bool ApplyOptionsToConnections(INTERNET_PER_CONN_OPTION_LIST& list)
{
  bool success = SetOptionsForConnection(list, nullptr);

  DWORD size = 0;
  DWORD count = 0;
  auto ret = RasEnumEntries(nullptr, nullptr, nullptr, &size, &count);
  if (ret == ERROR_BUFFER_TOO_SMALL && count > 0)
  {
    std::vector<RASENTRYNAME> entries(count);
    for (auto& entry : entries)
    {
      entry.dwSize = sizeof(RASENTRYNAME);
    }
    ret = RasEnumEntries(nullptr, nullptr, entries.data(), &size, &count);
    if (ret == ERROR_SUCCESS)
    {
      for (DWORD i = 0; i < count; i++)
      {
        success = SetOptionsForConnection(list, entries[i].szEntryName) && success;
      }
    }
    else
    {
      success = false;
    }
  }
  else if (ret != ERROR_SUCCESS)
  {
    success = false;
  }

  return success;
}

bool NotifySettingsChanged()
{
  const bool changed = InternetSetOption(
      nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0) != FALSE;
  const bool refreshed = InternetSetOption(
      nullptr, INTERNET_OPTION_REFRESH, nullptr, 0) != FALSE;
  return changed && refreshed;
}

bool startProxy(const int port, const flutter::EncodableList& bypassDomain)
{
  auto url = Utf8ToWide("127.0.0.1:" + std::to_string(port));
  auto bypassList = BuildBypassList(bypassDomain);
  std::vector<INTERNET_PER_CONN_OPTION> options(3);

  INTERNET_PER_CONN_OPTION_LIST list = {};
  list.dwSize = sizeof(list);
  list.dwOptionCount = static_cast<DWORD>(options.size());
  list.pOptions = options.data();

  options[0].dwOption = INTERNET_PER_CONN_FLAGS;
  options[0].Value.dwValue = PROXY_TYPE_DIRECT | PROXY_TYPE_PROXY;

  options[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
  options[1].Value.pszValue = url.data();

  options[2].dwOption = INTERNET_PER_CONN_PROXY_BYPASS;
  options[2].Value.pszValue = bypassList.data();

  return ApplyOptionsToConnections(list) && NotifySettingsChanged();
}

bool stopProxy()
{
  std::vector<INTERNET_PER_CONN_OPTION> options(1);

  INTERNET_PER_CONN_OPTION_LIST list = {};
  list.dwSize = sizeof(list);
  list.dwOptionCount = 1;
  list.pOptions = options.data();

  options[0].dwOption = INTERNET_PER_CONN_FLAGS;
  options[0].Value.dwValue = PROXY_TYPE_DIRECT;

  return ApplyOptionsToConnections(list) && NotifySettingsChanged();
}

bool ResetInterfaceRoutes(const NET_LUID& interface_luid)
{
  MIB_IPFORWARD_TABLE2* route_table = nullptr;
  const auto table_error = GetIpForwardTable2(AF_UNSPEC, &route_table);
  if (table_error != NO_ERROR)
  {
    return false;
  }

  bool success = true;
  for (ULONG i = 0; i < route_table->NumEntries; ++i)
  {
    auto& route = route_table->Table[i];
    if (route.InterfaceLuid.Value != interface_luid.Value)
    {
      continue;
    }
    const auto delete_error = DeleteIpForwardEntry2(&route);
    if (delete_error != NO_ERROR && delete_error != ERROR_NOT_FOUND)
    {
      success = false;
    }
  }

  FreeMibTable(route_table);
  return success;
}

bool ResetInterfaceMetric(const NET_LUID& interface_luid)
{
  bool success = true;
  for (const auto family : {AF_INET, AF_INET6})
  {
    MIB_IPINTERFACE_ROW interface_row = {};
    InitializeIpInterfaceEntry(&interface_row);
    interface_row.Family = family;
    interface_row.InterfaceLuid = interface_luid;

    const auto get_error = GetIpInterfaceEntry(&interface_row);
    if (get_error == ERROR_FILE_NOT_FOUND || get_error == ERROR_NOT_FOUND)
    {
      continue;
    }
    if (get_error != NO_ERROR)
    {
      success = false;
      continue;
    }

    interface_row.UseAutomaticMetric = TRUE;
    interface_row.Metric = 0;
    const auto set_error = SetIpInterfaceEntry(&interface_row);
    if (set_error != NO_ERROR && set_error != ERROR_FILE_NOT_FOUND &&
        set_error != ERROR_NOT_FOUND)
    {
      success = false;
    }
  }
  return success;
}

bool ResetFlClashTunInterface()
{
  try
  {
    ULONG addresses_size = 0;
    auto address_error = GetAdaptersAddresses(
        AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX, nullptr, nullptr, &addresses_size);
    if (address_error == ERROR_NO_DATA)
    {
      return true;
    }
    if (address_error != ERROR_BUFFER_OVERFLOW)
    {
      return false;
    }

    std::vector<BYTE> address_buffer(addresses_size);
    auto* addresses = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(address_buffer.data());
    address_error = GetAdaptersAddresses(
        AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX, nullptr, addresses, &addresses_size);
    if (address_error != NO_ERROR)
    {
      return false;
    }

    bool success = true;
    for (auto* adapter = addresses; adapter != nullptr; adapter = adapter->Next)
    {
      if (adapter->FriendlyName == nullptr ||
          std::wstring(adapter->FriendlyName) != L"FlClash")
      {
        continue;
      }
      success = ResetInterfaceRoutes(adapter->Luid) && success;
      success = ResetInterfaceMetric(adapter->Luid) && success;
    }
    return success;
  }
  catch (...)
  {
    return false;
  }
}

}  // namespace

namespace proxy
{

bool resetTunInterface()
{
  return ResetFlClashTunInterface();
}

void stopProxyForSessionEnd()
{
  stopProxy();
}

  // static
  void ProxyPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "proxy",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<ProxyPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result)
        {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  ProxyPlugin::ProxyPlugin() {}

  ProxyPlugin::~ProxyPlugin() {}

  void ProxyPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (method_call.method_name().compare("StopProxy") == 0)
    {
      result->Success(stopProxy());
    }
    else if (method_call.method_name().compare("ResetTunInterface") == 0)
    {
      result->Success(resetTunInterface());
    }
    else if (method_call.method_name().compare("StartProxy") == 0)
    {
      auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments == nullptr)
      {
        result->Error("bad_args", "StartProxy requires argument map");
        return;
      }
      auto portIt = arguments->find(flutter::EncodableValue("port"));
      auto bypassDomainIt = arguments->find(flutter::EncodableValue("bypassDomain"));
      if (portIt == arguments->end() || bypassDomainIt == arguments->end())
      {
        result->Error("bad_args", "StartProxy requires port and bypassDomain");
        return;
      }
      auto *port = std::get_if<int>(&portIt->second);
      auto *bypassDomain = std::get_if<flutter::EncodableList>(&bypassDomainIt->second);
      if (port == nullptr || bypassDomain == nullptr)
      {
        result->Error("bad_args", "StartProxy argument types are invalid");
        return;
      }
      result->Success(startProxy(*port, *bypassDomain));
    }
    else
    {
      result->NotImplemented();
    }
  }
} // namespace proxy
