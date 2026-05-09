enum AppLanguage {
  de('DE', 'Deutsch'),
  en('EN', 'English'),
  no('NO', 'Norsk'),
  da('DA', 'Dansk'),
  pl('PL', 'Polski'),
  ro('RO', 'Română'),
  bg('BG', 'Български'),
  tr('TR', 'Türkçe'),
  sr('SR', 'Српски');

  final String code;
  final String label;

  const AppLanguage(this.code, this.label);
}
