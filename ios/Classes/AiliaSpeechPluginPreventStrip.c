//
//  AiliSpeechPluginPreventStrip.c
//
//  Created by Kazuki Kyakuno on 2023/07/31.
//

// Dummy link to keep libailia_tokenizer.a from being deleted

extern const char* ailiaSpeechGetErrorDetail(void* net);

void test(void){
    ailiaSpeechGetErrorDetail(0);
}
