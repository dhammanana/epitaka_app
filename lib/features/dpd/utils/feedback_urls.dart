/// Opens DPD's own correction form in the browser. ePitaka has no in-app
/// feedback forms, so this is the only feedback path.
String buildMistakeUrl({String? word, int? headwordId, String? feedbackType}) {
  final url = StringBuffer(
    'https://docs.google.com/forms/d/e/1FAIpQLSf9boBe7k5tCwq7LdWgBHHGIPVc4ROO5yjVDo1X5LDAxkmGWQ/viewform?usp=pp_url',
  );

  if (word != null) {
    final encodedWord = Uri.encodeComponent(word);
    final wordIdentifier = headwordId != null
        ? '$headwordId%20$encodedWord'
        : encodedWord;
    url.write('&entry.438735500=$wordIdentifier');
  }
  if (feedbackType != null && feedbackType.isNotEmpty) {
    url.write('&entry.326955045=${Uri.encodeComponent(feedbackType)}');
  }

  url.write('&entry.1433863141=${Uri.encodeComponent('ePitaka')}');
  return url.toString();
}

/// DPD's form for a word the dictionary is missing.
String buildAddWordUrl() {
  return 'https://docs.google.com/forms/d/e/1FAIpQLSfResxEUiRCyFITWPkzoQ2HhHEvUS5fyg68Rl28hFH6vhHlaA/viewform?usp=pp_url'
      '&entry.1433863141=${Uri.encodeComponent('ePitaka')}';
}
