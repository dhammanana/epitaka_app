import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'tokenizer_service.dart';

/// Service for running the harrier Pali model via ONNX Runtime.
///
/// Steps:
/// 1. Load the ONNX model from file via [OnnxRuntime.createSession]
/// 2. Tokenize input text via [GavesanaTokenizerService]
/// 3. Run inference to get last_hidden_state
/// 4. Mean-pool to get sentence embedding (640-dim float32)
class GavesanaOnnxService {
  late final OnnxRuntime _ort;
  OrtSession? _session;
  bool _initialized = false;

  bool get isLoaded => _session != null && _initialized;

  /// Initialize ONNX Runtime and load the model.
  Future<void> init(String modelPath) async {
    if (_initialized) {
      print('[ONNX] init() called but already initialized');
      return;
    }

    print('[ONNX] ====== ONNX INIT ======');
    print('[ONNX] Model path: $modelPath');

    try {
      _ort = OnnxRuntime();
      print('[ONNX] Created OnnxRuntime instance');

      print('[ONNX] Calling createSession("$modelPath")…');
      _session = await _ort.createSession(modelPath);
      print('[ONNX] ✅ createSession() succeeded');

      _initialized = true;
      print('[ONNX] ====== ONNX INIT COMPLETE ✅ ======');
    } catch (e, stack) {
      print('[ONNX] ❌ ONNX init FAILED: $e');
      print('[ONNX] ❌ Stack: $stack');
      rethrow;
    }
  }

  /// Generate a 640-dim float32 embedding for the given text.
  /// Returns the raw float32 embedding that can be compared with DB vectors.
  Future<Float64List> generateEmbedding(
    GavesanaTokenizerService tokenizer,
    String text,
  ) async {
    if (!isLoaded || _session == null) {
      throw StateError('ONNX model not loaded. Call init() first.');
    }

    // 1. Tokenize
    final tokenized = tokenizer.tokenize(text);

    // 2. Prepare input tensors
    final inputIds = Int64List.fromList(tokenized.inputIds);
    final attentionMask = Int64List.fromList(tokenized.attentionMask);

    final shape = [1, tokenized.inputIds.length];

    final inputIdsTensor = await OrtValue.fromList(inputIds, shape);
    final attentionMaskTensor = await OrtValue.fromList(attentionMask, shape);

    // 3. Run inference
    final runOptions = OrtRunOptions();
    final outputs = await _session!.run(
      {
        'input_ids': inputIdsTensor,
        'attention_mask': attentionMaskTensor,
      },
      options: runOptions,
    );

    // 4. Read output: last_hidden_state [1, seq_len, 640]
    final outputTensor = outputs['last_hidden_state'] ?? outputs.values.first;
    final outputData = await outputTensor.asFlattenedList();

    // 5. Mean-pool over the sequence dimension (excluding padding)
    final embedding = _meanPool(
      outputData.cast<double>(),
      tokenized.inputIds.length,
      tokenized.attentionMask,
      640,
    );

    return embedding;
  }

  /// Mean-pool the last_hidden_state over the sequence dimension,
  /// excluding padding tokens (attention_mask == 0).
  Float64List _meanPool(
    List<double> hiddenStates,
    int seqLen,
    List<int> attentionMask,
    int dim,
  ) {
    final pooled = Float64List(dim);

    for (int s = 0; s < seqLen; s++) {
      if (attentionMask[s] == 0) continue;
      for (int d = 0; d < dim; d++) {
        pooled[d] += hiddenStates[s * dim + d];
      }
    }

    int validTokens = attentionMask.where((m) => m == 1).length;
    if (validTokens > 0) {
      for (int d = 0; d < dim; d++) {
        pooled[d] /= validTokens;
      }
    }

    return pooled;
  }

  /// Release the session and resources.
  Future<void> dispose() async {
    try {
      await _session?.close();
    } catch (_) {}
    _session = null;
    _initialized = false;
  }
}
