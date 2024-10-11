// ailia SDKとWhisperを使用して入力された音声からテキストを取得する

import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart'; // malloc
import 'package:ailia_speech/ailia_speech.dart' as ailia_speech_dart;
import 'package:ailia/ailia_license.dart';
import 'dart:convert';

String _ailiaCommonGetPath() {
  if (Platform.isAndroid || Platform.isLinux) {
    return 'libailia.so';
  }
  if (Platform.isMacOS) {
    return 'libailia.dylib';
  }
  if (Platform.isWindows) {
    return 'ailia.dll';
  }
  return 'internal';
}

String _ailiaCommonGetTokenizerPath() {
  if (Platform.isAndroid || Platform.isLinux) {
    return 'libailia_tokenizer.so';
  }
  if (Platform.isMacOS) {
    return 'libailia_tokenizer.dylib';
  }
  if (Platform.isWindows) {
    return 'ailia_tokenizer.dll';
  }
  return 'internal';
}

String _ailiaCommonGetAudioPath() {
  if (Platform.isAndroid || Platform.isLinux) {
    return 'libailia_audio.so';
  }
  if (Platform.isMacOS) {
    return 'libailia_audio.dylib';
  }
  if (Platform.isWindows) {
    return 'ailia_audio.dll';
  }
  return 'internal';
}

String _ailiaCommonGetSpeechPath() {
  if (Platform.isAndroid || Platform.isLinux) {
    return 'libailia_speech.so';
  }
  if (Platform.isMacOS) {
    return 'libailia_speech.dylib';
  }
  if (Platform.isWindows) {
    return 'ailia_speech.dll';
  }
  return 'internal';
}

ffi.DynamicLibrary _ailiaCommonGetLibrary(String path) {
  final ffi.DynamicLibrary library;
  if (Platform.isIOS) {
    library = ffi.DynamicLibrary.process();
  } else {
    library = ffi.DynamicLibrary.open(path);
  }
  return library;
}

class SpeechText {
  final String _text;
  final int _personId;
  final double _confidence;
  final double _timeStampBegin;
  final double _timeStampEnd;

  const SpeechText(
    this._text,
    this._personId,
    this._confidence,
    this._timeStampBegin,
    this._timeStampEnd,
  );

  factory SpeechText.fromPointer(
    ffi.Pointer<ailia_speech_dart.AILIASpeechText> text,
  ) {
    ffi.Pointer<Utf8> p = text.ref.text.cast<Utf8>();
    String s = p.toDartString();
    return SpeechText(
      s,
      text.ref.person_id,
      text.ref.confidence,
      text.ref.time_stamp_begin,
      text.ref.time_stamp_end,
    );
  }

  get text => _text;
  get confidence => _confidence;
  get timeStampBegin => _timeStampBegin;
  get timeStampEnd => _timeStampEnd;
  get personId => _personId;
  @override
  String toString() {
    // 分数と秒数を計算
    int beginMinutes = (_timeStampBegin / 60).floor();
    int beginSeconds = _timeStampBegin.toInt() % 60;

    int endMinutes = (_timeStampEnd / 60).floor();
    int endSeconds = _timeStampEnd.toInt() % 60;

    // 文字列としてフォーマット
    String beginTimeString =
        '$beginMinutes:${beginSeconds.toString().padLeft(2, '0')}';
    String endTimeString =
        '$endMinutes:${endSeconds.toString().padLeft(2, '0')}';

    return 'Text: $_text\n'
        'Person ID: $_personId\n'
        'Confidence: $_confidence\n'
        'Time Stamp (Begin): $beginTimeString\n'
        'Time Stamp (End): $endTimeString';
  }
}

class AiliaSpeechModel {
  ffi.DynamicLibrary? ailia;
  ffi.DynamicLibrary? ailiaTokenizer;
  ffi.DynamicLibrary? ailiaAudio;
  dynamic ailiaSpeech;
  ffi.Pointer<ffi.Pointer<ailia_speech_dart.AILIASpeech>>? ppAilia;
  bool available = false;
  bool debug = false;
  bool postProcess = false;

  // DLLから関数ポインタを取得
  // ailia_audio.dartから取得できるポインタはPrivate関数であり取得できないので、DLLから直接取得する
  ffi.Pointer<ailia_speech_dart.AILIASpeechApiCallback> getCallback() {
    ffi.Pointer<ailia_speech_dart.AILIASpeechApiCallback> callback =
        malloc<ailia_speech_dart.AILIASpeechApiCallback>();

    callback.ref.ailiaAudioGetFrameLen = ailiaAudio!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ffi.Int>,
              ffi.Int,
              ffi.Int,
              ffi.Int,
              ffi.Int,
            )>>('ailiaAudioGetFrameLen');
    callback.ref.ailiaAudioGetMelSpectrogram = ailiaAudio!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi.Void>,
              ffi.Int,
              ffi.Int,
              ffi.Int,
              ffi.Int,
              ffi.Int,
              ffi.Int,
              ffi.Int,
              ffi.Int,
              ffi.Float,
              ffi.Int,
              ffi.Float,
              ffi.Float,
              ffi.Int,
              ffi.Int,
              ffi.Int,
            )>>('ailiaAudioGetMelSpectrogram');
    callback.ref.ailiaAudioResample = ailiaAudio!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi.Void>,
              ffi.Int,
              ffi.Int,
              ffi.Int,
              ffi.Int,
            )>>('ailiaAudioResample');
    callback.ref.ailiaAudioGetResampleLen = ailiaAudio!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ffi.Int>,
              ffi.Int,
              ffi.Int,
              ffi.Int,
            )>>('ailiaAudioGetResampleLen');

    callback.ref.ailiaTokenizerCreate = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ffi.Pointer<ailia_speech_dart.AILIATokenizer>>,
              ffi.Int,
              ffi.Int,
            )>>('ailiaTokenizerCreate');
    callback.ref.ailiaTokenizerOpenModelFileA = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(ffi.Pointer<ailia_speech_dart.AILIATokenizer>,
                ffi.Pointer<ffi.Char>)>>('ailiaTokenizerOpenModelFileA');
    callback.ref.ailiaTokenizerOpenModelFileW = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(ffi.Pointer<ailia_speech_dart.AILIATokenizer>,
                ffi.Pointer<ffi.WChar>)>>('ailiaTokenizerOpenModelFileW');
    callback.ref.ailiaTokenizerEncode = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIATokenizer>,
              ffi.Pointer<ffi.Char>,
            )>>('ailiaTokenizerEncode');
    callback.ref.ailiaTokenizerGetTokenCount = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIATokenizer>,
              ffi.Pointer<ffi.UnsignedInt>,
            )>>('ailiaTokenizerGetTokenCount');
    callback.ref.ailiaTokenizerGetTokens = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIATokenizer>,
              ffi.Pointer<ffi.Int>,
              ffi.UnsignedInt,
            )>>('ailiaTokenizerGetTokens');
    callback.ref.ailiaTokenizerDecode = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIATokenizer>,
              ffi.Pointer<ffi.Int>,
              ffi.UnsignedInt,
            )>>('ailiaTokenizerDecode');
    callback.ref.ailiaTokenizerGetTextLength = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIATokenizer>,
              ffi.Pointer<ffi.UnsignedInt>,
            )>>('ailiaTokenizerGetTextLength');
    callback.ref.ailiaTokenizerGetText = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIATokenizer>,
              ffi.Pointer<ffi.Char>,
              ffi.UnsignedInt,
            )>>('ailiaTokenizerGetText');
    callback.ref.ailiaTokenizerDestroy = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Void Function(
              ffi.Pointer<ailia_speech_dart.AILIATokenizer>,
            )>>('ailiaTokenizerDestroy');
    callback.ref.ailiaTokenizerUtf8ToUtf32 = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ffi.UnsignedInt>,
              ffi.Pointer<ffi.UnsignedInt>,
              ffi.Pointer<ffi.Char>,
              ffi.UnsignedInt,
            )>>('ailiaTokenizerUtf8ToUtf32');
    callback.ref.ailiaTokenizerUtf32ToUtf8 = ailiaTokenizer!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.UnsignedInt>,
              ffi.UnsignedInt,
            )>>('ailiaTokenizerUtf32ToUtf8');

    callback.ref.ailiaCreate = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ffi.Pointer<ailia_speech_dart.AILIANetwork>>,
              ffi.Int,
              ffi.Int,
            )>>('ailiaCreate');
    callback.ref.ailiaOpenWeightFileA = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.Pointer<ffi.Char>,
            )>>('ailiaOpenWeightFileA');
    callback.ref.ailiaOpenWeightFileW = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.Pointer<ffi.WChar>,
            )>>('ailiaOpenWeightFileW');
    callback.ref.ailiaOpenWeightMem = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.Pointer<ffi.Void>,
              ffi.UnsignedInt,
            )>>('ailiaOpenWeightMem');
    callback.ref.ailiaSetMemoryMode = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.UnsignedInt,
            )>>('ailiaSetMemoryMode');
    callback.ref.ailiaDestroy = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Void Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
            )>>('ailiaDestroy');
    callback.ref.ailiaUpdate = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
            )>>('ailiaUpdate');
    callback.ref.ailiaGetBlobIndexByInputIndex = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.Pointer<ffi.UnsignedInt>,
              ffi.UnsignedInt,
            )>>('ailiaGetBlobIndexByInputIndex');
    callback.ref.ailiaGetBlobIndexByOutputIndex = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.Pointer<ffi.UnsignedInt>,
              ffi.UnsignedInt,
            )>>('ailiaGetBlobIndexByOutputIndex');
    callback.ref.ailiaGetBlobData = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.Pointer<ffi.Void>,
              ffi.UnsignedInt,
              ffi.UnsignedInt,
            )>>('ailiaGetBlobData');
    callback.ref.ailiaSetInputBlobData = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.Pointer<ffi.Void>,
              ffi.UnsignedInt,
              ffi.UnsignedInt,
            )>>('ailiaSetInputBlobData');
    callback.ref.ailiaSetInputBlobShape = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.Pointer<ailia_speech_dart.AILIAShape>,
              ffi.UnsignedInt,
              ffi.UnsignedInt,
            )>>('ailiaSetInputBlobShape');
    callback.ref.ailiaGetBlobShape = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.Pointer<ailia_speech_dart.AILIAShape>,
              ffi.UnsignedInt,
              ffi.UnsignedInt,
            )>>('ailiaGetBlobShape');
    callback.ref.ailiaGetErrorDetail = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Pointer<ffi.Char> Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
            )>>('ailiaGetErrorDetail');
    callback.ref.ailiaCopyBlobData = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.UnsignedInt,
              ffi.Pointer<ailia_speech_dart.AILIANetwork>,
              ffi.UnsignedInt,
            )>>('ailiaCopyBlobData');
    callback.ref.ailiaGetEnvironment = ailia!.lookup<
        ffi.NativeFunction<
            ffi.Int Function(
              ffi.Pointer<ffi.Pointer<ailia_speech_dart.AILIAEnvironment>>,
              ffi.UnsignedInt,
              ffi.UnsignedInt,
            )>>('ailiaGetEnvironment');

    return callback;
  }

  void throwError(String funcName, int code) {
    if (code != ailia_speech_dart.AILIA_STATUS_SUCCESS) {
      ffi.Pointer<Utf8> p =
          ailiaSpeech.ailiaSpeechGetErrorDetail(ppAilia!.value).cast<Utf8>();
      String errorDetail = p.toDartString();
      throw Exception("$funcName failed $code \n detail $errorDetail");
    }
  }

  String _pointerCharToString(ffi.Pointer<ffi.Char> pointer) {
    var length = 0;
    while (pointer.elementAt(length).value != 0) {
      length++;
    }

    var buffer = Uint8List(length);
    for (var i = 0; i < length; i++) {
      buffer[i] = pointer.elementAt(i).value;
    }

    return utf8.decode(buffer);
  }

  static Map<int, Function(String)> callbacks = {};
  static int classIdCounter = 0;

  int classId = 0;

  // fromFunction expects a static function as parameter. dart:ffi only supports calling static Dart functions from native code.

  static int intermediateCallback(
    ffi.Pointer<ffi.Void> handle,
    ffi.Pointer<ffi.Char> text,
  ) {
    int refClassId = handle.address;
    if (!callbacks.containsKey(refClassId)){
      return 0;
    }
    Function(String) callback = callbacks[refClassId]!;
    callback(text.cast<Utf8>().toDartString());
    return 0; // 1で中断
  }

  // インスタンスを作成する
  void create(
    bool liveTranscribe,
    bool taskTranslate,
    int envId,
    {bool virtualMemory = false}
  ) {
    ailiaSpeech = ailia_speech_dart.ailiaSpeechFFI(
      _ailiaCommonGetLibrary(_ailiaCommonGetSpeechPath()),
    );

    ailiaAudio = _ailiaCommonGetLibrary(_ailiaCommonGetAudioPath());
    ailia = _ailiaCommonGetLibrary(_ailiaCommonGetPath());
    ailiaTokenizer = _ailiaCommonGetLibrary(_ailiaCommonGetTokenizerPath());

    ppAilia = malloc<ffi.Pointer<ailia_speech_dart.AILIASpeech>>();

    ffi.Pointer<ailia_speech_dart.AILIASpeechApiCallback> callback =
        getCallback();

    int memoryMode = ailia_speech_dart.AILIA_MEMORY_REDUCE_CONSTANT |
        ailia_speech_dart.AILIA_MEMORY_REDUCE_CONSTANT_WITH_INPUT_INITIALIZER |
        ailia_speech_dart.AILIA_MEMORY_REUSE_INTERSTAGE;
    if (virtualMemory){
        memoryMode = ailia_speech_dart.AILIA_MEMORY_REDUCE_CONSTANT |
                ailia_speech_dart.AILIA_MEMORY_REDUCE_CONSTANT_WITH_INPUT_INITIALIZER |
                ailia_speech_dart.AILIA_MEMORY_REUSE_INTERSTAGE |
                ailia_speech_dart.AILIA_MEMORY_REDUCE_CONSTANT_WITH_FILE_MAPPED;
    }
    int taskId = ailia_speech_dart.AILIA_SPEECH_TASK_TRANSCRIBE;
    if (taskTranslate) {
      taskId = ailia_speech_dart.AILIA_SPEECH_TASK_TRANSLATE;
    }
    int flag = ailia_speech_dart.AILIA_SPEECH_FLAG_NONE;
    if (liveTranscribe) {
      flag = ailia_speech_dart.AILIA_SPEECH_FLAG_LIVE;
    }

    int status = ailiaSpeech.ailiaSpeechCreate(
      ppAilia,
      envId,
      ailia_speech_dart.AILIA_MULTITHREAD_AUTO,
      memoryMode,
      taskId,
      flag,
      callback.ref,
      ailia_speech_dart.AILIA_SPEECH_API_CALLBACK_VERSION,
    );
    throwError("ailiaSpeechCreate", status);
    malloc.free(callback);
  }

  // モデルを開く
  void open(
    File encoder,
    File decoder,
    File? vad,
    String language,
    int modelType
  ) {
    classId = classIdCounter;
    classIdCounter++;

    int status = 0;
    if (Platform.isWindows) {
      status = ailiaSpeech.ailiaSpeechOpenModelFileW(
        ppAilia!.value,
        encoder.path.toNativeUtf16().cast<ffi.Int16>(),
        decoder.path.toNativeUtf16().cast<ffi.Int16>(),
        modelType,
      );
    } else {
      status = ailiaSpeech.ailiaSpeechOpenModelFileA(
        ppAilia!.value,
        encoder.path.toNativeUtf8().cast<ffi.Int8>(),
        decoder.path.toNativeUtf8().cast<ffi.Int8>(),
        modelType,
      );
    }
    throwError("ailiaSpeechOpenModelFileA", status);

    if (language != "auto") {
      status = ailiaSpeech.ailiaSpeechSetLanguage(
        ppAilia!.value,
        language.toNativeUtf8().cast<ffi.Int8>(),
      );
      throwError("ailiaSpeechSetLanguage", status);
    }

    if (vad != null) {
      if (Platform.isWindows) {
        status = ailiaSpeech.ailiaSpeechOpenVadFileW(
          ppAilia!.value,
          vad.path.toNativeUtf16().cast<ffi.Int16>(),
          ailia_speech_dart.AILIA_SPEECH_VAD_TYPE_SILERO,
        );
      } else {
        status = ailiaSpeech.ailiaSpeechOpenVadFileA(
          ppAilia!.value,
          vad.path.toNativeUtf8().cast<ffi.Int8>(),
          ailia_speech_dart.AILIA_SPEECH_VAD_TYPE_SILERO,
        );
      }
      throwError("ailiaSpeechOpenVadFileA", status);
    }

    ailia_speech_dart.AILIA_SPEECH_USER_API_INTERMEDIATE_CALLBACK pointer =
        ffi.Pointer.fromFunction(intermediateCallback, 0);
    ffi.Pointer<ffi.Void> voidPointer =
        ffi.Pointer<ffi.Void>.fromAddress(classId);

    status = ailiaSpeech.ailiaSpeechSetIntermediateCallback(
      ppAilia!.value,
      pointer,
      voidPointer,
    );
    throwError("ailiaSpeechSetIntermediateCallback", status);

    /*
    bool dictionary = (strcmp(option, "dictionary") == 0);
    if (dictionary){
      status = ailiaSpeechOpenDictionaryFileA(net, "dict.csv", AILIA_SPEECH_DICTIONARY_TYPE_REPLACE);
      if (status != AILIA_STATUS_SUCCESS){
        printf("ailiaSpeechOpenDictionaryFileA Error %d\n", status);
      }
    }
    */

    if (vad != null) {
      const double thresholdVad = 0.5;
      const double speechSec = 1.0;
      const double noSpeechSec = 1.0;
      status = ailiaSpeech.ailiaSpeechSetSilentThreshold(
        ppAilia!.value,
        thresholdVad,
        speechSec,
        noSpeechSec,
      );
      throwError("ailiaSpeechSetSilentThreshold", status);
    }

    available = true;
    postProcess = false;
  }

  // ポストプロセスのモデルを開く
  void postprocess(
    File encoder,
    File? decoder,
    File source,
    File target,
    bool jaEn,
  ) {
    int status = ailiaSpeech.ailiaSpeechOpenPostProcessFileA(
      ppAilia!.value,
      encoder.path.toNativeUtf8().cast<ffi.Int8>(),
      (decoder == null)
          ? ffi.nullptr
          : decoder.path.toNativeUtf8().cast<ffi.Int8>(),
      source.path.toNativeUtf8().cast<ffi.Int8>(),
      target.path.toNativeUtf8().cast<ffi.Int8>(),
      ffi.nullptr,
      (jaEn)
          ? ailia_speech_dart.AILIA_SPEECH_POST_PROCESS_TYPE_FUGUMT_JA_EN
          : ailia_speech_dart.AILIA_SPEECH_POST_PROCESS_TYPE_FUGUMT_EN_JA,
    );
    throwError("ailiaSpeechOpenPostProcessFileA", status);
    postProcess = true;
  }

  // モデルを閉じる
  void close() {
    ffi.Pointer<ailia_speech_dart.AILIASpeech> net = ppAilia!.value;
    ailiaSpeech.ailiaSpeechDestroy(net);
    malloc.free(ppAilia!);

    available = false;
  }

  // 途中の文字起こしの結果の通知を行うコールバックを設定する
  void setIntermediateCallback(Function(String) callback){
    if (!available) {
      throw Exception("Model not opened yet. wait one second and try again.");
    }
    callbacks[classId] = callback;
  }

  // 文字起こしを行うデータが存在するか
  bool isBuffered() {
    // Check enough pcm exists in queue
    final ffi.Pointer<ffi.UnsignedInt> buffered = malloc<ffi.UnsignedInt>();
    int status = ailiaSpeech.ailiaSpeechBuffered(ppAilia!.value, buffered);
    throwError("ailiaSpeechBuffered", status);
    if (buffered.value == 0) {
      malloc.free(buffered);
      return false;
    }
    malloc.free(buffered);
    return true;
  }

  // 文字起こしを1回だけ実行する
  List<SpeechText> transcribe() {
    List<SpeechText> result = [];
    // Process
    int status = ailiaSpeech.ailiaSpeechTranscribe(ppAilia!.value);
    throwError("ailiaSpeechTranscribe", status);
    if (postProcess) {
      status = ailiaSpeech.ailiaSpeechPostProcess(ppAilia!.value);
      throwError("ailiaSpeechTranscribe", status);
    }

    // Get results
    final ffi.Pointer<ffi.UnsignedInt> count = malloc<ffi.UnsignedInt>();
    status = ailiaSpeech.ailiaSpeechGetTextCount(ppAilia!.value, count);
    throwError("ailiaSpeechGetTextCount", status);

    for (int idx = 0; idx < count.value; idx++) {
      final ffi.Pointer<ailia_speech_dart.AILIASpeechText> text =
          malloc<ailia_speech_dart.AILIASpeechText>();
      status = ailiaSpeech.ailiaSpeechGetText(
        ppAilia!.value,
        text,
        ailia_speech_dart.AILIA_SPEECH_TEXT_VERSION,
        idx,
      );
      throwError("ailiaSpeechGetText", status);

      SpeechText s = SpeechText.fromPointer(text);
      result.add(s);

      malloc.free(text);
    }
    malloc.free(count);
    return result;
  }

  // 文字起こしをまとめて実行する
  List<SpeechText> transcribeBatch() {
    List<SpeechText> result = [];
    while (isBuffered()) {
      List<SpeechText> newResult = transcribe();
      result.addAll(newResult);
    }
    return result;
  }

  // ストリームの終端かを確認する
  bool isComplete() {
    final ffi.Pointer<ffi.UnsignedInt> completed = malloc<ffi.UnsignedInt>();
    int status = ailiaSpeech.ailiaSpeechComplete(ppAilia!.value, completed);
    throwError("ailiaSpeechComplete", status);
    bool complete = false;
    if (completed.value == 1) {
      complete = true;
    }
    malloc.free(completed);
    return complete;
  }

  // ストリームにPCMを投入する
  void pushInputData(
    List<double> pcm,
    int sampleRate,
    int nChannels
  ) {
    if (!available) {
      throw Exception("Model not opened yet. wait one second and try again.");
    }

    ffi.Pointer<ffi.Float> waveBuf = malloc<ffi.Float>(pcm.length);
    for (int i = 0; i < pcm.length; i++) {
      waveBuf[i] = pcm[i];
    }

    int status = 0;
    int pushSamples = pcm.length;
    status = ailiaSpeech.ailiaSpeechPushInputData(
      ppAilia!.value,
      waveBuf,
      nChannels,
      pushSamples ~/ nChannels,
      sampleRate,
    );
    throwError("ailiaSpeechPushInputData", status);

    malloc.free(waveBuf);
  }

  // 終端であることを通知する
  void finalizeInputData() {
    if (!available) {
      throw Exception("Model not opened yet. wait one second and try again.");
    }

    int status = ailiaSpeech.ailiaSpeechFinalizeInputData(ppAilia!.value);
    throwError("ailiaSpeechFinalizeInputData", status);
  }

  // ストリームの終了処理を行う
  void reset() {
    if (!available) {
      throw Exception("Model not opened yet. wait one second and try again.");
    }

    // Reset state
    int status = ailiaSpeech.ailiaSpeechResetTranscribeState(ppAilia!.value);
    throwError("ailiaSpeechResetTranscribeState", status);
  }

  // 翻訳を行う
  String translate(String inputText) {
    final ffi.Pointer<ailia_speech_dart.AILIASpeechText> inputTextStruct =
        malloc<ailia_speech_dart.AILIASpeechText>();

    String language = "ja";
    inputTextStruct.ref.text = inputText.toNativeUtf8().cast<ffi.Char>();
    inputTextStruct.ref.time_stamp_begin = 0.0;
    inputTextStruct.ref.time_stamp_end = 0.0;
    inputTextStruct.ref.person_id = 0;
    inputTextStruct.ref.language = language.toNativeUtf8().cast<ffi.Char>();

    int status = ailiaSpeech.ailiaSpeechSetText(
      ppAilia!.value,
      inputTextStruct,
      ailia_speech_dart.AILIA_SPEECH_TEXT_VERSION,
      0,
    );
    throwError("ailiaSpeechTranscribe", status);

    if (!postProcess) {
      throwError("must open postprocess model", -1);
    }

    status = ailiaSpeech.ailiaSpeechPostProcess(ppAilia!.value);
    throwError("ailiaSpeechTranscribe", status);

    final ffi.Pointer<ailia_speech_dart.AILIASpeechText> text =
        malloc<ailia_speech_dart.AILIASpeechText>();
    status = ailiaSpeech.ailiaSpeechGetText(
      ppAilia!.value,
      text,
      ailia_speech_dart.AILIA_SPEECH_TEXT_VERSION,
      0,
    );
    throwError("ailiaSpeechGetText", status);

    ffi.Pointer<Utf8> p = text.ref.text.cast<Utf8>();
    String result = p.toDartString();

    malloc.free(text);
    malloc.free(inputTextStruct);

    return result;
  }
}
