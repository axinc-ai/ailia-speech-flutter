#include "include/ailia_speech/ailia_speech_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "ailia_speech_plugin.h"

void AiliaSpeechPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ailia_speech::AiliaSpeechPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
