/// Konstanten für Sattelzüge
class TrailerConstants {
  /// Innenbreite des Sattelzugs in cm
  static const double trailerWidthCm = 240;

  /// Innenlänge des Sattelzugs in cm
  static const double trailerLengthCm = 1360;

  /// Euro-Palette Länge in cm
  static const double euroLengthCm = 120;

  /// Euro-Palette Breite in cm
  static const double euroWidthCm = 80;

  /// Industrie-Palette Länge in cm
  static const double industryLengthCm = 120;

  /// Industrie-Palette Breite in cm
  static const double industryWidthCm = 100;

  /// Maximales Gesamtgewicht in kg
  static const double maxGrossWeight = 40000;

  /// Eigengewicht des Sattelzugs in kg
  static const double trailerTareWeight = 2500;

  /// Maximale Ladefähigkeit in kg
  static double get maxPayload => maxGrossWeight - trailerTareWeight;
}

enum TrailerType {
  standard,
  frigo;

  double get trailerLengthCm {
    switch (this) {
      case TrailerType.standard:
        return 1360;
      case TrailerType.frigo:
        return 1340;
    }
  }

  double get trailerWidthCm => 240;

  int get maxEuroPallets {
    switch (this) {
      case TrailerType.standard:
        return 33;
      case TrailerType.frigo:
        return 33;
    }
  }

  String get label {
    switch (this) {
      case TrailerType.standard:
        return 'Standard';
      case TrailerType.frigo:
        return 'Frigo';
    }
  }
}
