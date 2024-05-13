//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <ailia/ailia_plugin.h>
#include <ailia_speech/ailia_speech_plugin.h>
#include <ailia_tokenizer/ailia_tokenizer_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) ailia_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AiliaPlugin");
  ailia_plugin_register_with_registrar(ailia_registrar);
  g_autoptr(FlPluginRegistrar) ailia_speech_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AiliaSpeechPlugin");
  ailia_speech_plugin_register_with_registrar(ailia_speech_registrar);
  g_autoptr(FlPluginRegistrar) ailia_tokenizer_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AiliaTokenizerPlugin");
  ailia_tokenizer_plugin_register_with_registrar(ailia_tokenizer_registrar);
}
