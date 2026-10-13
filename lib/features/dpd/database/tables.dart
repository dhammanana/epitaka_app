import 'package:drift/drift.dart';

// Computed fields pre-built by dpd-db mobile exporter (not in source DB):
// - DpdRoots.rootCount: COUNT of headwords with each root
// - DpdHeadwords.lemmaIpa: IPA transcription via Aksharamukha (IASTPali -> IPA)

class DpdHeadwords extends Table {
  IntColumn get id => integer()();
  TextColumn get lemma1 => text().named('lemma_1')();
  TextColumn get lemma2 => text().named('lemma_2').nullable()();
  TextColumn get pos => text().nullable()();
  TextColumn get grammar => text().nullable()();
  TextColumn get derivedFrom => text().named('derived_from').nullable()();
  TextColumn get neg => text().nullable()();
  TextColumn get verb => text().nullable()();
  TextColumn get trans => text().nullable()();
  TextColumn get plusCase => text().named('plus_case').nullable()();
  TextColumn get meaning1 => text().named('meaning_1').nullable()();
  TextColumn get meaningLit => text().named('meaning_lit').nullable()();
  TextColumn get meaning2 => text().named('meaning_2').nullable()();
  TextColumn get rootKey =>
      text().named('root_key').references(DpdRoots, #root).nullable()();
  TextColumn get rootSign => text().named('root_sign').nullable()();
  TextColumn get rootBase => text().named('root_base').nullable()();
  TextColumn get familyRoot => text().named('family_root').nullable()();
  TextColumn get familyWord => text().named('family_word').nullable()();
  TextColumn get familyCompound => text().named('family_compound').nullable()();
  TextColumn get familyIdioms => text().named('family_idioms').nullable()();
  TextColumn get familySet => text().named('family_set').nullable()();
  TextColumn get construction => text().nullable()();
  TextColumn get compoundType => text().named('compound_type').nullable()();
  TextColumn get compoundConstruction =>
      text().named('compound_construction').nullable()();
  TextColumn get source1 => text().named('source_1').nullable()();
  TextColumn get sutta1 => text().named('sutta_1').nullable()();
  TextColumn get example1 => text().named('example_1').nullable()();
  TextColumn get source2 => text().named('source_2').nullable()();
  TextColumn get sutta2 => text().named('sutta_2').nullable()();
  TextColumn get example2 => text().named('example_2').nullable()();
  TextColumn get antonym => text().nullable()();
  TextColumn get synonym => text().nullable()();
  TextColumn get variant => text().nullable()();
  TextColumn get stem => text().nullable()();
  TextColumn get pattern => text().nullable()();
  TextColumn get derivative => text().nullable()();
  TextColumn get suffix => text().nullable()();
  TextColumn get freqData => text().named('freq_data').nullable()();
  TextColumn get lemmaIpa => text().named('lemma_ipa').nullable()();
  IntColumn get ebtCount => integer().named('ebt_count').nullable()();
  TextColumn get nonIa => text().named('non_ia').nullable()();
  TextColumn get sanskrit => text().nullable()();
  TextColumn get cognate => text().nullable()();
  TextColumn get link => text().nullable()();
  TextColumn get phonetic => text().nullable()();
  TextColumn get varPhonetic => text().named('var_phonetic').nullable()();
  TextColumn get varText => text().named('var_text').nullable()();
  TextColumn get origin => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get commentary => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Lookup extends Table {
  TextColumn get lookupKey => text().named('lookup_key')();
  TextColumn get headwords => text().nullable()();
  TextColumn get roots => text().nullable()();
  TextColumn get variant => text().nullable()();
  TextColumn get see => text().nullable()();
  TextColumn get spelling => text().nullable()();
  TextColumn get grammar => text().nullable()();
  TextColumn get help => text().nullable()();
  TextColumn get abbrev => text().nullable()();
  TextColumn get abbrevOther => text().named('abbrev_other').nullable()();
  TextColumn get deconstructor => text().nullable()();
  TextColumn get epd => text().nullable()();
  TextColumn get fuzzyKey => text().named('fuzzy_key').nullable()();

  @override
  Set<Column> get primaryKey => {lookupKey};
}

class DpdRoots extends Table {
  TextColumn get root => text()();
  TextColumn get rootInComps => text().named('root_in_comps')();
  TextColumn get rootHasVerb => text().named('root_has_verb')();
  IntColumn get rootGroup => integer().named('root_group')();
  TextColumn get rootSign => text().named('root_sign')();
  TextColumn get rootMeaning => text().named('root_meaning')();
  TextColumn get sanskritRoot => text().named('sanskrit_root')();
  TextColumn get sanskritRootMeaning => text().named('sanskrit_root_meaning')();
  TextColumn get sanskritRootClass => text().named('sanskrit_root_class')();
  TextColumn get rootExample => text().named('root_example')();
  TextColumn get dhatupathaNum => text().named('dhatupatha_num')();
  TextColumn get dhatupathaRoot => text().named('dhatupatha_root')();
  TextColumn get dhatupathaPali => text().named('dhatupatha_pali')();
  TextColumn get dhatupathaEnglish => text().named('dhatupatha_english')();
  TextColumn get dhatumanjusaNum => text().named('dhatumanjusa_num')();
  TextColumn get dhatumanjusaRoot => text().named('dhatumanjusa_root')();
  TextColumn get dhatumanjusaPali => text().named('dhatumanjusa_pali')();
  TextColumn get dhatumanjusaEnglish => text().named('dhatumanjusa_english')();
  TextColumn get dhatumalaRoot => text().named('dhatumala_root')();
  TextColumn get dhatumalaPali => text().named('dhatumala_pali')();
  TextColumn get dhatumalaEnglish => text().named('dhatumala_english')();
  TextColumn get paniniRoot => text().named('panini_root')();
  TextColumn get paniniSanskrit => text().named('panini_sanskrit')();
  TextColumn get paniniEnglish => text().named('panini_english')();
  TextColumn get note => text().named('note')();
  IntColumn get rootCount => integer().named('root_count').nullable()();

  @override
  Set<Column> get primaryKey => {root};
}

class InflectionTemplates extends Table {
  TextColumn get pattern => text()();
  TextColumn get templateLike => text().named('like').nullable()();
  TextColumn get data => text()();

  @override
  Set<Column> get primaryKey => {pattern};
}

class DbInfo extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

class FamilyRoot extends Table {
  @override
  String get tableName => 'family_root';

  TextColumn get rootFamilyKey => text().named('root_family_key')();
  TextColumn get rootKey => text().named('root_key')();
  TextColumn get rootFamily => text().named('root_family')();
  TextColumn get rootMeaning => text().named('root_meaning')();
  TextColumn get html => text()();
  TextColumn get data => text()();
  IntColumn get count => integer()();

  @override
  Set<Column> get primaryKey => {rootFamilyKey};
}

class FamilyWord extends Table {
  @override
  String get tableName => 'family_word';

  TextColumn get wordFamily => text().named('word_family')();
  TextColumn get data => text()();
  IntColumn get count => integer()();

  @override
  Set<Column> get primaryKey => {wordFamily};
}

class FamilyCompound extends Table {
  @override
  String get tableName => 'family_compound';

  TextColumn get compoundFamily => text().named('compound_family')();
  TextColumn get data => text()();
  IntColumn get count => integer()();

  @override
  Set<Column> get primaryKey => {compoundFamily};
}

class FamilyIdiom extends Table {
  @override
  String get tableName => 'family_idiom';

  TextColumn get idiom => text()();
  TextColumn get data => text()();
  IntColumn get count => integer()();

  @override
  Set<Column> get primaryKey => {idiom};
}

class SuttaInfo extends Table {
  @override
  String get tableName => 'sutta_info';

  // DPD
  TextColumn get book => text().nullable()();
  TextColumn get bookCode => text().named('book_code').nullable()();
  TextColumn get dpdCode => text().named('dpd_code').nullable()();
  TextColumn get dpdSutta => text().named('dpd_sutta')();
  TextColumn get dpdSuttaVar => text().named('dpd_sutta_var').nullable()();

  // CST
  TextColumn get cstCode => text().named('cst_code').nullable()();
  TextColumn get cstNikaya => text().named('cst_nikaya').nullable()();
  TextColumn get cstBook => text().named('cst_book').nullable()();
  TextColumn get cstSection => text().named('cst_section').nullable()();
  TextColumn get cstVagga => text().named('cst_vagga').nullable()();
  TextColumn get cstSutta => text().named('cst_sutta').nullable()();
  TextColumn get cstParanum => text().named('cst_paranum').nullable()();
  TextColumn get cstMPage => text().named('cst_m_page').nullable()();
  TextColumn get cstVPage => text().named('cst_v_page').nullable()();
  TextColumn get cstPPage => text().named('cst_p_page').nullable()();
  TextColumn get cstTPage => text().named('cst_t_page').nullable()();
  TextColumn get cstFile => text().named('cst_file').nullable()();

  // Sutta Central
  TextColumn get scCode => text().named('sc_code').nullable()();
  TextColumn get scBook => text().named('sc_book').nullable()();
  TextColumn get scVagga => text().named('sc_vagga').nullable()();
  TextColumn get scSutta => text().named('sc_sutta').nullable()();
  TextColumn get scEngSutta => text().named('sc_eng_sutta').nullable()();
  TextColumn get scBlurb => text().named('sc_blurb').nullable()();
  TextColumn get scFilePath => text().named('sc_file_path').nullable()();
  TextColumn get dprCode => text().named('dpr_code').nullable()();
  TextColumn get dprLink => text().named('dpr_link').nullable()();

  // BJT
  TextColumn get bjtSuttaCode => text().named('bjt_sutta_code').nullable()();
  TextColumn get bjtWebCode => text().named('bjt_web_code').nullable()();
  TextColumn get bjtFilename => text().named('bjt_filename').nullable()();
  TextColumn get bjtBookId => text().named('bjt_book_id').nullable()();
  TextColumn get bjtPageNum => text().named('bjt_page_num').nullable()();
  TextColumn get bjtPageOffset => text().named('bjt_page_offset').nullable()();
  TextColumn get bjtPitaka => text().named('bjt_piṭaka').nullable()();
  TextColumn get bjtNikaya => text().named('bjt_nikāya').nullable()();
  TextColumn get bjtMajorSection =>
      text().named('bjt_major_section').nullable()();
  TextColumn get bjtBook => text().named('bjt_book').nullable()();
  TextColumn get bjtMinorSection =>
      text().named('bjt_minor_section').nullable()();
  TextColumn get bjtVagga => text().named('bjt_vagga').nullable()();
  TextColumn get bjtSutta => text().named('bjt_sutta').nullable()();

  // Dhamma Vinaya
  TextColumn get dvPts => text().named('dv_pts').nullable()();
  TextColumn get dvMainTheme => text().named('dv_main_theme').nullable()();
  TextColumn get dvSubtopic => text().named('dv_subtopic').nullable()();
  TextColumn get dvSummary => text().named('dv_summary').nullable()();
  TextColumn get dvSimiles => text().named('dv_similes').nullable()();
  TextColumn get dvKeyExcerpt1 => text().named('dv_key_excerpt1').nullable()();
  TextColumn get dvKeyExcerpt2 => text().named('dv_key_excerpt2').nullable()();
  TextColumn get dvStage => text().named('dv_stage').nullable()();
  TextColumn get dvTraining => text().named('dv_training').nullable()();
  TextColumn get dvAspect => text().named('dv_aspect').nullable()();
  TextColumn get dvTeacher => text().named('dv_teacher').nullable()();
  TextColumn get dvAudience => text().named('dv_audience').nullable()();
  TextColumn get dvMethod => text().named('dv_method').nullable()();
  TextColumn get dvLength => text().named('dv_length').nullable()();
  TextColumn get dvProminence => text().named('dv_prominence').nullable()();
  TextColumn get dvNikayasParallels =>
      text().named('dv_nikayas_parallels').nullable()();
  TextColumn get dvAgamasParallels =>
      text().named('dv_āgamas_parallels').nullable()();
  TextColumn get dvTaishoParallels =>
      text().named('dv_taisho_parallels').nullable()();
  TextColumn get dvSanskritParallels =>
      text().named('dv_sanskrit_parallels').nullable()();
  TextColumn get dvVinayaParallels =>
      text().named('dv_vinaya_parallels').nullable()();
  TextColumn get dvOthersParallels =>
      text().named('dv_others_parallels').nullable()();
  TextColumn get dvPartialParallelsNa =>
      text().named('dv_partial_parallels_nā').nullable()();
  TextColumn get dvPartialParallelsAll =>
      text().named('dv_partial_parallels_all').nullable()();
  TextColumn get dvSuggestedSuttas =>
      text().named('dv_suggested_suttas').nullable()();

  @override
  Set<Column> get primaryKey => {dpdSutta};
}

class DictMeta extends Table {
  @override
  String get tableName => 'dict_meta';

  TextColumn get dictId => text().named('dict_id')();
  TextColumn get name => text()();
  TextColumn get author => text().nullable()();
  TextColumn get css => text().nullable()();
  IntColumn get entryCount => integer().named('entry_count').nullable()();

  @override
  Set<Column> get primaryKey => {dictId};
}

class DictEntries extends Table {
  @override
  String get tableName => 'dict_entries';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get dictId => text().named('dict_id')();
  TextColumn get word => text()();
  TextColumn get wordFuzzy => text().named('word_fuzzy').nullable()();
  TextColumn get definitionHtml => text().named('definition_html').nullable()();
  TextColumn get definitionPlain =>
      text().named('definition_plain').nullable()();
}

class FamilySet extends Table {
  @override
  String get tableName => 'family_set';

  TextColumn get set_ => text().named('set')();
  TextColumn get data => text()();
  IntColumn get count => integer()();

  @override
  Set<Column> get primaryKey => {set_};
}
