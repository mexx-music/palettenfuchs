/// Typen von Paletten
enum PalletType {
  euro('Euro-Palette', 120, 80),
  industrial('Industrie-Palette', 120, 100);

  final String label;
  final double width;  // in cm
  final double length; // in cm

  const PalletType(this.label, this.width, this.length);
}

/// Verschiedene Anordnungsoptionen für Palettenreihen
enum RowArrangement {
  euroLongi3('Euro längs (3er)', 3, 120), // 3 Paletten à 80cm = 240cm Breite
  euroTransverse2('Euro quer (2er)', 2, 80), // 2 Paletten à 120cm = 240cm Breite
  euroTransverseSingle('Euro quer (einzeln)', 1, 80), // 1 Palette à 120cm
  industryLongi2('Industrie quer (2er)', 2, 100), // 2 Paletten à 120cm = 240cm Breite, 100cm in Fahrtrichtung
  industrySingle('Industrie (einzeln)', 1, 120); // 1 Palette à 120cm

  final String label;
  final int palletCount; // Anzahl Paletten nebeneinander
  final double lengthCm; // Länge der Reihe in cm

  const RowArrangement(this.label, this.palletCount, this.lengthCm);
}

