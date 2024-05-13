#ifndef FLUTTER_PLUGIN_AILIA_SPEECH_PLUGIN_H_
#define FLUTTER_PLUGIN_AILIA_SPEECH_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace ailia_speech {

class AiliaSpeechPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AiliaSpeechPlugin();

  virtual ~AiliaSpeechPlugin();

  // Disallow copy and assign.
  AiliaSpeechPlugin(const AiliaSpeechPlugin&) = delete;
  AiliaSpeechPlugin& operator=(const AiliaSpeechPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace ailia_speech

#endif  // FLUTTER_PLUGIN_AILIA_SPEECH_PLUGIN_H_
