/// Compile-time legal identity for a production store build.
///
/// The defaults intentionally keep a debug build usable but make a release
/// build fail closed until the real data controller and the approved legal
/// texts have been supplied by the product owner.
class LegalConfig {
  static const entityName = String.fromEnvironment('LEGAL_ENTITY_NAME');
  static const contactEmail = String.fromEnvironment('LEGAL_CONTACT_EMAIL');
  static const postalAddress = String.fromEnvironment('LEGAL_POSTAL_ADDRESS');
  static const approved = bool.fromEnvironment(
    'LEGAL_APPROVED',
    defaultValue: false,
  );

  static bool get isComplete =>
      entityName.trim().isNotEmpty &&
      contactEmail.trim().isNotEmpty &&
      postalAddress.trim().isNotEmpty &&
      approved;

  static String get displayedEntity =>
      entityName.trim().isEmpty ? 'BriefAI Germany' : entityName;

  static String get displayedContact =>
      contactEmail.trim().isEmpty ? 'Kontakt nije konfigurisan' : contactEmail;

  static String get displayedAddress => postalAddress.trim().isEmpty
      ? 'Adresa nije konfigurisana'
      : postalAddress;
}
