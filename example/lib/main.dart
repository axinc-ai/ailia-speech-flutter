import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wav/wav.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/services.dart';
import 'package:ailia_speech/ailia_speech.dart' as ailia_speech_dart;
import 'package:ailia_speech/ailia_speech_model.dart';
import 'package:ailia/ailia_license.dart';

import 'utils/download_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _ailiaSpeechModel = AiliaSpeechModel();
  String _predictText = "Initializing...";

  @override
  void initState() {
    super.initState();
    _ailiaSpeechTest();
  }

  void _intermediateCallback(String text){
    setState(() {
      _predictText = text;
    });
  }

  Future<File> copyFileFromAssets(String path) async {
    final byteData = await rootBundle.load('assets/$path');
    final buffer = byteData.buffer;
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    var filePath = '$tempPath/$path';
    return File(filePath)
      .writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, 
    byteData.lengthInBytes));
  }

  void progressCallback(String file, int size) {
      setState(() {
        _predictText = "Downloading ${file} ${size / 1024} KB";
      });
  }

  void _ailiaSpeechTest() async{
    await AiliaLicense.checkAndDownloadLicense();

    // Load image
    ByteData data = await rootBundle.load("assets/demo.wav");
    final wav = await Wav.read(data.buffer.asUint8List());

    // Load dict if you want to use word replace
    File dict = await copyFileFromAssets("dict.csv");

    // Model Selection
    String remotePath = "https://storage.googleapis.com/ailia-models/whisper/";
    String encoderModelPath = "encoder_tiny.opt3.onnx";
    String decoderModelPath = "decoder_tiny_fix_kv_cache.opt3.onnx";
    int modelType = ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_WHISPER_MULTILINGUAL_TINY;

    bool sensevoice = true;
    if (sensevoice) {
      remotePath = "https://storage.googleapis.com/ailia-models/sensevoice/";
      encoderModelPath = "sensevoice_small.onnx";
      decoderModelPath = "sensevoice_small.model";
      modelType = ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_SENSEVOICE_SMALL;
    }

    print("Downloading model...");
    downloadModel(remotePath + encoderModelPath, encoderModelPath, progressCallback, (onnx_encoder_file) {
      downloadModel(remotePath + decoderModelPath, decoderModelPath, progressCallback, (onnx_decoder_file) {
        downloadModel("https://storage.googleapis.com/ailia-models/silero-vad/silero_vad.onnx", "silero_vad.onnx", progressCallback, (onnx_vad_file) {
          downloadModel("https://storage.googleapis.com/ailia-models/pyannote-audio/segmentation.onnx", "segmentation.onnx", progressCallback, (onnx_segmentation_file) {
            downloadModel("https://storage.googleapis.com/ailia-models/pyannote-audio/speaker-embedding.onnx", "speaker-embedding.onnx", progressCallback, (onnx_embedding_gile) {
              print("Download model success");

              _ailiaSpeechModel.create(false, false, ailia_speech_dart.AILIA_ENVIRONMENT_ID_AUTO);
              // onnx_vad_file is optional
              _ailiaSpeechModel.open(onnx_encoder_file, onnx_decoder_file, onnx_vad_file, "auto", modelType);
              _ailiaSpeechModel.diarization(onnx_segmentation_file, onnx_embedding_gile); // optional
              _ailiaSpeechModel.dictionary(dict); // optional

              List<double> pcm = List<double>.empty(growable: true);

              for (int i = 0; i < wav.channels[0].length; ++i) {
                for (int j = 0; j < wav.channels.length; ++j){
                  pcm.add(wav.channels[j][i]);
                }
              }

              //_ailiaSpeechModel.setIntermediateCallback(_intermediateCallback);
              _ailiaSpeechModel.pushInputData(pcm, wav.samplesPerSecond, wav.channels.length);

              _ailiaSpeechModel.finalizeInputData();

              String transcribe_result = "";

              List<SpeechText> texts = _ailiaSpeechModel.transcribeBatch();
              for (int i = 0; i < texts.length; i++){
                String speakerId = "${texts[i].personId}";
                if (texts[i].personId == ailia_speech_dart.AILIA_SPEECH_SPEAKER_ID_UNKNOWN) {
                  speakerId = "UNK";
                }
                transcribe_result = transcribe_result + "\n${texts[i].timeStampBegin} - ${texts[i].timeStampEnd} Speaker.${speakerId} " + texts[i].text;
              }

              _ailiaSpeechModel.close();

              print("Sueccess");

              setState(() {
                _predictText = transcribe_result;
              });
            });
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('ailia AI Speech Flutter Plugin Example'),
        ),
        body: Center(
          child: Text('Result : $_predictText\n'),
        ),
      ),
    );
  }
}
