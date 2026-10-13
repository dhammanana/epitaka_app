import 'dpd_database.dart';

// Strips Pāḷi diacritical marks to plain ASCII — for SC URL slug construction.
// Unlike stripDiacritics in utils/diacritics.dart, this does NOT strip aspirates
// or double consonants, matching Python's NFD-decompose + strip-Mn approach.
String _paliSlug(String s) {
  const map = <int, String>{
    0x0101: 'a', // ā
    0x0100: 'a', // Ā
    0x012B: 'i', // ī
    0x012A: 'i', // Ī
    0x016B: 'u', // ū
    0x016A: 'u', // Ū
    0x1E45: 'n', // ṅ
    0x1E44: 'n', // Ṅ
    0x00F1: 'n', // ñ
    0x00D1: 'n', // Ñ
    0x1E6D: 't', // ṭ
    0x1E6C: 't', // Ṭ
    0x1E0D: 'd', // ḍ
    0x1E0C: 'd', // Ḍ
    0x1E47: 'n', // ṇ
    0x1E46: 'n', // Ṇ
    0x1E41: 'm', // ṁ
    0x1E40: 'm', // Ṁ
    0x1E43: 'm', // ṃ
    0x1E42: 'm', // Ṃ
    0x1E37: 'l', // ḷ
    0x1E36: 'l', // Ḷ
    0x1E3B: 'l', // ḻ
    0x1E25: 'h', // ḥ
    0x1E24: 'h', // Ḥ
  };
  final buf = StringBuffer();
  for (final rune in s.runes) {
    buf.write(map[rune] ?? String.fromCharCode(rune));
  }
  return buf.toString().toLowerCase();
}

extension SuttaInfoExtensions on SuttaInfoData {
  bool _notEmpty(String? s) => s != null && s.isNotEmpty;

  // ── Sutta Central links ──────────────────────────────────────────────────

  String? get scCardLink =>
      _notEmpty(scCode) ? 'https://suttacentral.net/$scCode' : null;

  String? get scPaliLink =>
      _notEmpty(scCode) ? 'https://suttacentral.net/$scCode/pli/ms' : null;

  String? get scEngLink => _notEmpty(scCode)
      ? 'https://suttacentral.net/$scCode/en/sujato'
      : null;

  String? get scGithub => _notEmpty(scFilePath)
      ? 'https://github.com/suttacentral/sc-data/blob/main/$scFilePath'
      : null;

  String? get scExpressLink => _notEmpty(scCode)
      ? 'https://suttacentral.express/${scCode!.toLowerCase()}/en/sujato'
      : null;

  String? get scVoiceLink => _notEmpty(scCode)
      ? 'https://www.sc-voice.net/#/sutta/${scCode!.toLowerCase()}/en/sujato'
      : null;

  String? get dhammaGift => _notEmpty(scCode)
      ? 'https://dhamma.gift/${scCode!.toLowerCase()}'
      : null;

  // s.4nt.org container pages (SN saṃyutta, AN nipāta, KN book) embed one TOC
  // anchor id per sutta/verse, almost always exactly `sc_code.lower()`. These
  // 45 sc_codes are the exceptions where the site groups things differently
  // than DPD does — mirrors `_S4NT_ANCHOR_OVERRIDES` in `db/models.py`.
  static const _s4ntAnchorOverrides = {
    'AN3.156': 'an3.156-162',
    'AN3.163': 'an3.163-182',
    'DHP1-20': 'dhp1',
    'DHP100-115': 'dhp100',
    'DHP116-128': 'dhp116',
    'DHP129-145': 'dhp129',
    'DHP146-156': 'dhp146',
    'DHP157-166': 'dhp157',
    'DHP167-178': 'dhp167',
    'DHP179-196': 'dhp179',
    'DHP197-208': 'dhp197',
    'DHP209-220': 'dhp209',
    'DHP21-32': 'dhp21',
    'DHP221-234': 'dhp221',
    'DHP235-255': 'dhp235',
    'DHP256-272': 'dhp256',
    'DHP273-289': 'dhp273',
    'DHP290-305': 'dhp290',
    'DHP306-319': 'dhp306',
    'DHP320-333': 'dhp320',
    'DHP33-43': 'dhp33',
    'DHP334-359': 'dhp334',
    'DHP360-382': 'dhp360',
    'DHP383-423': 'dhp383',
    'DHP44-59': 'dhp44',
    'DHP60-75': 'dhp60',
    'DHP76-89': 'dhp76',
    'DHP90-00': 'dhp90',
    'SN12.83': 'sn12.83-92',
    'SN12.93-103': 'sn12.93-213',
    'SN23.23': 'sn23.23-33',
    'SN23.35': 'sn23.35-45',
    'SN33.11': 'sn33.11-15',
    'SN33.16': 'sn33.16-20',
    'SN33.51': 'sn33.51-54',
    'SN34.46': 'sn34.46-49',
    'SN34.50': 'sn34.50-52',
    'SN34.53': 'sn34.53-54',
    'SN35.33': 'sn35.33-42',
    'SN35.43': 'sn35.43-51',
    'SN43.14': 'sn43.14-43',
    'SN45.104': 'sn45.104-108',
    'SN45.110': 'sn45.110-114',
    'SN45.116': 'sn45.116-120',
    'SN45.141': 'sn45.141-145',
  };

  static const _s4ntKnBooks = {
    'kp', 'dhp', 'ud', 'iti', 'snp', 'vv', 'pv', 'thag', 'thig', 'ja', 'mnd',
    'cnd', 'ps', 'ne', 'pe', 'cp', 'bv', 'mil', 'tha-ap', 'thi-ap',
  };

  // Mirrors Python SuttaInfo.s_4nt_link — there is no raw DB column for this.
  String? get s4ntLink {
    final scBookCode = _scBookCode;
    if (!_notEmpty(scCode) || !_notEmpty(scBookCode)) return null;

    final book = scBookCode!.replaceAll(RegExp(r'-+$'), '').toLowerCase();
    final code = scCode!.toLowerCase();

    if (book == 'dn' || book == 'mn') {
      return 'https://s.4nt.org/$book/$code/index.html';
    }

    if (book == 'sn' || book == 'an') {
      final m = RegExp('^$book(\\d+)').firstMatch(code);
      if (m == null) return null;
      final path = '$book/$book${m.group(1)}';
      if (code == '$book${m.group(1)}') {
        return 'https://s.4nt.org/$path/index.html';
      }
      final fragment = _s4ntAnchorOverrides[scCode] ?? code;
      return 'https://s.4nt.org/$path/index.html#$fragment';
    }

    if (_s4ntKnBooks.contains(book)) {
      final fragment = _s4ntAnchorOverrides[scCode] ?? code;
      return 'https://s.4nt.org/kn/$book/index.html#$fragment';
    }

    return null;
  }

  // ── The Buddha's Words links ─────────────────────────────────────────────

  static const _tbwBookCodes = {
    'DN', 'MN', 'SN', 'AN', 'KHP', 'DHP', 'UD', 'ITI', 'SNP', 'TH', 'THI',
  };

  String? get _scBookCode {
    if (!_notEmpty(scCode)) return null;
    return scCode!.replaceAll(RegExp(r'\d+\.*-*\d*'), '');
  }

  String? get tbw {
    if (!_notEmpty(scCode) || !_tbwBookCodes.contains(bookCode)) return null;
    final code = _scBookCode!.toLowerCase();
    if (code == 'iti') return 'https://thebuddhaswords.net/it/it.html';
    return 'https://thebuddhaswords.net/$code/${scCode!.toLowerCase()}.html';
  }

  String? get tbwLegacy {
    if (!_notEmpty(scCode) || !_tbwBookCodes.contains(bookCode)) return null;
    final code = _scBookCode!.toLowerCase();
    if (code == 'iti') return 'https://f.dhamma.gift/bw/it/it.html';
    return 'https://f.dhamma.gift/bw/$code/${scCode!.toLowerCase()}.html';
  }

  // ── CST links ──────────────────────────────────────────────────────────

  String? get cstGithubLink => _notEmpty(cstFile)
      ? 'https://github.com/VipassanaTech/tipitaka-xml/tree/main/$cstFile'
      : null;

  String? get tprLink {
    if (!_notEmpty(dpdCode)) return null;
    return 'tpr.pali.tools://open/?sutta=${dpdCode!.toLowerCase()}';
  }

  // ── CST / TPP links ─────────────────────────────────────────────────────

  String? get tppOrg {
    if (!_notEmpty(cstCode) || !_notEmpty(cstFile)) return null;
    final tppCode = cstFile!.replaceAll(RegExp(r'romn/|\.xml'), '');
    return 'https://tipitakapali.org/book/$tppCode#para$cstParanum';
  }

  // ── BJT links ────────────────────────────────────────────────────────────

  String? get bjtGithubLink => _notEmpty(bjtFilename)
      ? 'https://github.com/pathnirvana/tipitaka.lk/blob/master/public/static/text/$bjtFilename.json'
      : null;

  String? get bjtTipitakaLkLink =>
      _notEmpty(bjtWebCode) ? 'https://tipitaka.lk/$bjtWebCode' : null;

  String? get bjtOpenTipitakaLkLink =>
      _notEmpty(bjtWebCode) ? 'https://open.tipitaka.lk/latn/$bjtWebCode' : null;

  String? get bjtOpenTipitakaLkDevanagariLink =>
      _notEmpty(bjtWebCode) ? 'https://open.tipitaka.lk/deva/$bjtWebCode' : null;

  // ── DV existence checks ──────────────────────────────────────────────────

  bool get dvExists =>
      _notEmpty(dvPts) ||
      _notEmpty(dvMainTheme) ||
      _notEmpty(dvSubtopic) ||
      _notEmpty(dvSummary) ||
      _notEmpty(dvSimiles) ||
      _notEmpty(dvKeyExcerpt1) ||
      _notEmpty(dvKeyExcerpt2) ||
      _notEmpty(dvStage) ||
      _notEmpty(dvTraining) ||
      _notEmpty(dvAspect) ||
      _notEmpty(dvTeacher) ||
      _notEmpty(dvAudience) ||
      _notEmpty(dvMethod) ||
      _notEmpty(dvLength) ||
      _notEmpty(dvProminence) ||
      _notEmpty(dvSuggestedSuttas) ||
      dvParallelsExists;

  bool get dvParallelsExists =>
      _notEmpty(dvNikayasParallels) ||
      _notEmpty(dvAgamasParallels) ||
      _notEmpty(dvTaishoParallels) ||
      _notEmpty(dvSanskritParallels) ||
      _notEmpty(dvVinayaParallels) ||
      _notEmpty(dvOthersParallels) ||
      _notEmpty(dvPartialParallelsNa) ||
      _notEmpty(dvPartialParallelsAll);

  // ── Entry-type classifiers (mirrors Python SuttaInfo.is_vagga / is_samyutta) ─

  bool get isVagga {
    final names = [dpdSutta, dpdSuttaVar ?? ''];
    if (names.any((n) => n.contains('vagga') || n.contains('vaggo'))) return true;
    return (dpdCode ?? '').contains('-') &&
        (_notEmpty(cstVagga) || _notEmpty(scVagga) || _notEmpty(bjtVagga));
  }

  bool get isSamyutta {
    if (dpdSutta.isEmpty || !_notEmpty(dpdCode)) return false;
    if (dpdCode!.contains('.') || dpdCode!.contains('-')) return false;
    // Strip trailing homonym number (e.g. "jhānasaṃyutta 1" → "jhānasaṃyutta")
    final base = dpdSutta.replaceFirst(RegExp(r' \d+$'), '');
    return base.endsWith('saṃyutta');
  }

  bool get isNipata {
    if (dpdSutta.isEmpty || !_notEmpty(dpdCode)) return false;
    if (dpdCode!.contains('.') || dpdCode!.contains('-')) return false;
    final names = [dpdSutta, dpdSuttaVar ?? ''];
    return names.any((n) => n.contains('nipāta'));
  }

  // Mirrors Python SuttaInfo.sc_vagga_link — constructs SC vagga/saṃyutta URL.
  String? get scVaggaLink {
    final bookCode = _scBookCode;
    if (bookCode == null) return null;
    final bc = bookCode.toLowerCase();

    // DHP: verse range directly in dpd_code (e.g. dhp76-89)
    if (bc == 'dhp' && _notEmpty(dpdCode)) {
      return 'https://suttacentral.net/${dpdCode!.toLowerCase()}';
    }

    // SN individual saṃyutta: pitaka path with parent-vagga slug + saṃyutta number
    if (bc == 'sn' && isSamyutta && _notEmpty(dpdCode)) {
      final m = RegExp(r'^SN(\d+)$', caseSensitive: false).firstMatch(dpdCode!);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        String? slug;
        if (n >= 1 && n <= 11) { slug = 'sagathavaggasamyutta'; }
        else if (n >= 12 && n <= 21) { slug = 'nidanavaggasamyutta'; }
        else if (n >= 22 && n <= 34) { slug = 'khandhavaggasamyutta'; }
        else if (n >= 35 && n <= 44) { slug = 'salayatanavaggasamyutta'; }
        else if (n >= 45 && n <= 56) { slug = 'mahavaggasamyutta'; }
        if (slug != null) {
          return 'https://suttacentral.net/pitaka/sutta/linked/sn/sn-$slug/sn$n';
        }
      }
      return null;
    }

    // AN individual nipāta: pitaka path with nipāta number (e.g. AN1 → an1)
    if (bc == 'an' && isNipata && _notEmpty(dpdCode)) {
      final m = RegExp(r'^AN(\d+)$', caseSensitive: false).firstMatch(dpdCode!);
      if (m != null) {
        return 'https://suttacentral.net/pitaka/sutta/numbered/an/an${m.group(1)}';
      }
      return null;
    }

    // SN vaggasaṃyuttapāḷi: slug from dpdSutta minus "pāḷi" suffix
    if (bc == 'sn' && dpdSutta.endsWith('saṃyuttapāḷi')) {
      final name = dpdSutta.replaceFirst(RegExp(r'pāḷi$'), '');
      return 'https://suttacentral.net/pitaka/sutta/linked/sn/sn-${_paliSlug(name)}';
    }

    // MN paṇṇāsapāḷi: slug from dpdSutta minus "pāḷi" suffix
    if (bc == 'mn' && dpdSutta.endsWith('paṇṇāsapāḷi')) {
      final name = dpdSutta.replaceFirst(RegExp(r'pāḷi$'), '');
      return 'https://suttacentral.net/pitaka/sutta/middle/mn/mn-${_paliSlug(name)}';
    }

    // DN vaggapāḷi: slug from dpdSutta minus "pāḷi" suffix
    if (bc == 'dn' && dpdSutta.endsWith('vaggapāḷi')) {
      final name = dpdSutta.replaceFirst(RegExp(r'pāḷi$'), '');
      return 'https://suttacentral.net/dn-${_paliSlug(name)}';
    }

    // Generic: derive slug from sc_vagga (strip leading "N. " numbering)
    if (!_notEmpty(scVagga)) return null;
    final vaggaName = scVagga!.replaceFirst(RegExp(r'^\d+\.\s*'), '');
    final slug = _paliSlug(vaggaName);
    // SN/AN include section number in prefix (e.g. SN12.1-10 → sn12)
    final m2 = RegExp(r'^([A-Za-z]+)(\d+)\.(\d+)').firstMatch(dpdCode ?? '');
    final prefix = m2 != null ? '${m2.group(1)!}${m2.group(2)!}'.toLowerCase() : bc;
    return 'https://suttacentral.net/$prefix-$slug';
  }
}
