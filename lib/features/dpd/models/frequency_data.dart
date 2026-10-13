import 'dart:convert';

class FrequencyData {
  const FrequencyData({
    required this.freqHeading,
    required this.cstFreq,
    required this.cstGrad,
    required this.bjtFreq,
    required this.bjtGrad,
    required this.syaFreq,
    required this.syaGrad,
    required this.scFreq,
    required this.scGrad,
  });

  final String freqHeading;
  final List<int> cstFreq;
  final List<int> cstGrad;
  final List<int> bjtFreq;
  final List<int> bjtGrad;
  final List<int> syaFreq;
  final List<int> syaGrad;
  final List<int> scFreq;
  final List<int> scGrad;

  bool get isEmpty => freqHeading.isEmpty;

  bool get isNoExactMatches =>
      freqHeading.contains('no exact matches');

  factory FrequencyData.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return FrequencyData(
      freqHeading: map['FreqHeading'] as String? ?? '',
      cstFreq: _parseIntList(map['CstFreq']),
      cstGrad: _parseIntList(map['CstGrad']),
      bjtFreq: _parseIntList(map['BjtFreq']),
      bjtGrad: _parseIntList(map['BjtGrad']),
      syaFreq: _parseIntList(map['SyaFreq']),
      syaGrad: _parseIntList(map['SyaGrad']),
      scFreq: _parseIntList(map['ScFreq']),
      scGrad: _parseIntList(map['ScGrad']),
    );
  }

  static List<int> _parseIntList(dynamic value) {
    if (value == null) return [];
    return (value as List<dynamic>).map((e) => (e as num).toInt()).toList();
  }
}

FrequencyData? parseFrequencyData(String? jsonData) {
  if (jsonData == null || jsonData.isEmpty) return null;
  try {
    return FrequencyData.fromJson(jsonData);
  } catch (_) {
    return null;
  }
}
