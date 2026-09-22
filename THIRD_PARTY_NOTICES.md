# Third-party notices

Jev Nodge incorporates and modifies code from
[`mikakostoev/jev-voice-control`](https://github.com/mikakostoev/jev-voice-control),
used under the MIT License. The original copyright notice is retained in
`LICENSE`.

The project also draws architectural ideas from these MIT-licensed projects:

- [`kevinbadi/jev-voice`](https://github.com/kevinbadi/jev-voice)
- [`browser-use/jev-ultrafast`](https://github.com/browser-use/jev-ultrafast)
- [`jcpsimmons/jev-macos-loop`](https://github.com/jcpsimmons/jev-macos-loop)

No source code from the latter three projects is currently vendored.

Local spoken replies use these open-source components:

- [`OpenMOSS/MOSS-TTS-Nano`](https://github.com/OpenMOSS/MOSS-TTS-Nano),
  including its MOSS Audio Tokenizer, under the Apache License 2.0
- [`kyinwind/MOSSTTSKit`](https://github.com/kyinwind/MOSSTTSKit) under the
  Apache License 2.0
- [Microsoft ONNX Runtime](https://github.com/microsoft/onnxruntime) under the
  MIT License
- [Hugging Face Swift Transformers](https://github.com/huggingface/swift-transformers)
  under the Apache License 2.0

The MOSS model files are downloaded on first use and cached on the user's Mac.
