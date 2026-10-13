enum FeedbackType {
  grammar('Grammar'),
  examples('Examples'),
  inflection('Inflection'),
  rootFamily('Root Family'),
  wordFamily('Word Family'),
  compoundFamily('Compound Family'),
  idioms('Idioms'),
  set('Set'),
  frequency('Frequency'),
  rootInfo('Root Info'),
  rootMatrix('Root Matrix'),
  suttaInfo('Sutta');

  final String value;
  const FeedbackType(this.value);
}
