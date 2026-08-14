class PreparedEmail {
  const PreparedEmail({required this.subject, required this.body});

  final String subject;
  final String body;

  Uri toMailtoUri() => Uri.parse(
    'mailto:?subject=${Uri.encodeComponent(subject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
}

/// Prepares an AI-generated German email for native mail applications.
///
/// The generated response may contain a leading `Betreff:` line. Mail clients
/// already have a dedicated subject field, so that line is extracted instead
/// of being duplicated in the message body. CRLF line endings keep paragraph
/// order stable across Apple Mail, Gmail and Outlook.
PreparedEmail prepareGeneratedEmail({
  required String fallbackSubject,
  required String generatedBody,
}) {
  final normalized = generatedBody
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  final lines = normalized.split('\n');
  var subject = fallbackSubject.trim();

  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines.removeAt(0);
  }

  if (lines.isNotEmpty) {
    final match = RegExp(
      r'^\s*\*{0,2}(?:Betreff|Subject)\*{0,2}\s*:\s*(.+?)\s*$',
      caseSensitive: false,
    ).firstMatch(lines.first);
    if (match != null) {
      final generatedSubject = match
          .group(1)!
          .replaceAll(RegExp(r'^\*+|\*+$'), '')
          .trim();
      if (generatedSubject.isNotEmpty) subject = generatedSubject;
      lines.removeAt(0);
      while (lines.isNotEmpty && lines.first.trim().isEmpty) {
        lines.removeAt(0);
      }
    }
  }

  final body = lines.join('\n').trim().replaceAll('\n', '\r\n');
  return PreparedEmail(subject: subject, body: body);
}
