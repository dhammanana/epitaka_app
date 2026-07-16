import 'dart:convert';
import 'dart:io';

import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';

/// Wrapper around the BPE tokenizer for the harrier Pali model.
///
/// Loads a HuggingFace tokenizer.json file using the
/// dart_sentencepiece_tokenizer package and provides tokenization
/// for ONNX model inference (input_ids + attention_mask).
class GavesanaTokenizerService {
  SentencePieceTokenizer? _tokenizer;
  int? _clsTokenId;
  int? _sepTokenId;
  int? _padTokenId;

  bool get isLoaded => _tokenizer != null;

  /// Max sequence length for the model.
  static const int maxSeqLen = 256;

  /// Load tokenizer from a tokenizer.json file.
  ///
  /// Pre-processes the merges from list-of-lists format
  /// ([["a", "b"], ...]) to string format (["a b", ...]) which is
  /// what HuggingFaceTokenizerLoader expects. The harrier 270M Pali
  /// model uses the list-of-lists format.
  Future<void> load(String tokenizerJsonPath) async {
    print('[TOKENIZER] ====== LOAD START ======');
    print('[TOKENIZER] Path: $tokenizerJsonPath');

    try {
      final file = File(tokenizerJsonPath);
      print('[TOKENIZER] Reading file…');
      final jsonStr = await file.readAsString();
      print('[TOKENIZER] File read (${jsonStr.length} chars)');

      print('[TOKENIZER] Decoding JSON…');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      print('[TOKENIZER] JSON decoded successfully');

      // ── Normalise merges to string format ────────────────────────
      print('[TOKENIZER] Checking merges format…');
      final modelData = json['model'] as Map<String, dynamic>?;
      if (modelData != null) {
        final merges = modelData['merges'];
        if (merges is List && merges.isNotEmpty && merges.first is List) {
          print('[TOKENIZER] Converting merges from list-of-lists to string format');
          modelData['merges'] = merges
              .map((m) => (m as List).join(' '))
              .toList();
          print('[TOKENIZER]   Converted ${(modelData['merges'] as List).length} merges');
        }
      }

      // Load the tokenizer using the HuggingFace static method.
      print('[TOKENIZER] Creating HuggingFaceTokenizerLoader.fromMap()…');
      _tokenizer = HuggingFaceTokenizerLoader.fromMap(json);
      print('[TOKENIZER] ✅ Tokenizer loaded successfully');

      // Find special token IDs from added_tokens.
      print('[TOKENIZER] Finding special token IDs…');
      final addedTokens = json['added_tokens'] as List<dynamic>? ?? [];
      for (final t in addedTokens) {
        final map = t as Map<String, dynamic>;
        final id = (map['id'] as num).toInt();
        final content = map['content'] as String;
        if (content == '<pad>') _padTokenId ??= id;
        if (content == '<bos>' || content == '<s>') _clsTokenId ??= id;
        if (content == '<eos>' || content == '</s>') _sepTokenId ??= id;
      }

      // Default values if not found in added_tokens
      _padTokenId ??= 0;
      _clsTokenId ??= 1;
      _sepTokenId ??= 2;
      print('[TOKENIZER] Special token IDs: pad=$_padTokenId, cls=$_clsTokenId, sep=$_sepTokenId');
      print('[TOKENIZER] ====== LOAD COMPLETE ✅ ======');
    } catch (e, stack) {
      print('[TOKENIZER] ❌ Load FAILED: $e');
      print('[TOKENIZER] ❌ Stack: $stack');
      rethrow;
    }
  }

  /// Tokenize a text string into token IDs.
  /// Returns input_ids and attention_mask padded to [maxSeqLen].
  TokenizerOutput tokenize(String text) {
    if (_tokenizer == null) {
      throw StateError('Tokenizer not loaded');
    }

    // Tokenize using the SentencePieceTokenizer
    final encoding = _tokenizer!.encode(text);

    // Build input_ids with special tokens
    final ids = <int>[];
    if (_clsTokenId != null) ids.add(_clsTokenId!);
    ids.addAll(encoding.ids);
    if (_sepTokenId != null) ids.add(_sepTokenId!);

    // Truncate to max sequence length (keep CLS and SEP)
    if (ids.length > maxSeqLen) {
      final truncated = <int>[ids.first];
      truncated.addAll(ids.skip(1).take(maxSeqLen - 2));
      truncated.add(ids.last);
      ids
        ..clear()
        ..addAll(truncated);
    }

    // Pad to maxSeqLen
    while (ids.length < maxSeqLen) {
      ids.add(_padTokenId ?? 0);
    }

    // Build attention mask
    final attentionMask = List.generate(
      maxSeqLen,
      (i) => i < ids.length && ids[i] != (_padTokenId ?? 0) ? 1 : 0,
    );

    return TokenizerOutput(
      inputIds: ids.take(maxSeqLen).toList(),
      attentionMask: attentionMask,
    );
  }

  /// Decode token IDs back to text.
  String decode(List<int> ids) {
    if (_tokenizer == null) return '';
    // Filter out special tokens
    final filtered = ids.where((id) =>
        id != _padTokenId && id != _clsTokenId && id != _sepTokenId).toList();
    return _tokenizer!.decode(filtered);
  }
}

/// Output of tokenization.
class TokenizerOutput {
  final List<int> inputIds;
  final List<int> attentionMask;

  const TokenizerOutput({
    required this.inputIds,
    required this.attentionMask,
  });
}
