class PreparedEmail {
  const PreparedEmail({required this.subject, required this.body});

  final String subject;
  final String body;

  Uri toMailtoUri() => Uri(
    scheme: 'mailto',
    query:
        'subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}',
  );
}

/// Converts model output into portable Unicode plain text before it reaches
/// the clipboard, a mail client or a PDF renderer.
///
/// In particular, this removes Markdown-only decoration and control
/// characters that some Android mail clients render as boxes or stray signs.
/// It deliberately keeps ordinary non-ASCII letters such as č, ć, š, ä and ß.
String preparePlainTextForExport(String value) {
  var normalized = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u2028', '\n')
      .replaceAll('\u2029', '\n')
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u200B', '')
      .replaceAll('\uFEFF', '');

  // A doubly escaped model response has visible "\\n" sequences but no
  // real line breaks. Recover its paragraphs without altering normal text.
  if (!normalized.contains('\n') && normalized.contains(r'\n')) {
    normalized = normalized.replaceAll(r'\n', '\n');
  }

  normalized = normalized
      .replaceAll(RegExp(r'^\s*```(?:text|markdown)?\s*$', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*```\s*$', multiLine: true), '')
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
      .replaceAll(
        RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
        '',
      );
  normalized = normalized
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (match) => match.group(1)!)
      .replaceAllMapped(RegExp(r'__(.+?)__'), (match) => match.group(1)!);

  return normalized.trim();
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
  final normalized = preparePlainTextForExport(generatedBody);
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
