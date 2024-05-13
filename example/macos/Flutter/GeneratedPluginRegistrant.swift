//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import ailia
import ailia_speech
import ailia_tokenizer
import path_provider_foundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AiliaPlugin.register(with: registry.registrar(forPlugin: "AiliaPlugin"))
  AiliaSpeechPlugin.register(with: registry.registrar(forPlugin: "AiliaSpeechPlugin"))
  AiliaTokenizerPlugin.register(with: registry.registrar(forPlugin: "AiliaTokenizerPlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
}
