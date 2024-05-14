import 'package:flutter/material.dart';
import 'package:wav/wav.dart';

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

  void _ailiaSpeechTest() async{
    await AiliaLicense.checkAndDownloadLicense();

    // Load image
    ByteData data = await rootBundle.load("assets/demo.wav");
    final wav = await Wav.read(data.buffer.asUint8List());

    print("Downloading model...");
    downloadModel("https://storage.googleapis.com/ailia-models/whisper/encoder_tiny.opt3.onnx", "encoder_tiny.opt3.onnx", (onnx_encoder_file) {
      downloadModel("https://storage.googleapis.com/ailia-models/whisper/decoder_tiny_fix_kv_cache.opt3.onnx", "decoder_tiny_fix_kv_cache.opt3.onnx", (onnx_decoder_file) {
        print("Download model success");

        _ailiaSpeechModel.create(false, false, ailia_speech_dart.AILIA_ENVIRONMENT_ID_AUTO);
        _ailiaSpeechModel.open(onnx_encoder_file, onnx_decoder_file, null, "auto", ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_WHISPER_MULTILINGUAL_TINY);

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
          transcribe_result = transcribe_result + texts[i].text;
        }
        

        _ailiaSpeechModel.close();

        print("Sueccess");

        setState(() {
          _predictText = transcribe_result;
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
