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

  /// Zulässiges Gesamtgewicht in kg (EU-Norm Sattelzug, 5 Achsen)
  static const double maxGrossWeight = 40000;

  /// Eigengewicht der Zugmaschine in kg
  static const double tractorTareWeight = 7500;
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

  /// Theoretisches Maximum (GVW − Fahrzeuggewichte), gesetzliche Obergrenze
  double get theoreticalMaxPayloadKg {
    switch (this) {
      case TrailerType.standard:
        return 25500;
      case TrailerType.frigo:
        return 24000;
    }
  }

  /// Praxisgrenze: empfohlenes Ladegewicht im Tagesgeschäft
  double get practicalMaxPayloadKg {
    switch (this) {
      case TrailerType.standard:
        return 24500;
      case TrailerType.frigo:
        return 23000;
    }
  }

  /// Warnschwelle: ab hier auf Gesamtgewicht achten
  double get payloadWarningKg {
    switch (this) {
      case TrailerType.standard:
        return 24000;
      case TrailerType.frigo:
        return 22500;
    }
  }

  /// Kritische Schwelle: nahe oder über 40 t
  double get payloadCriticalKg {
    switch (this) {
      case TrailerType.standard:
        return 25000;
      case TrailerType.frigo:
        return 23500;
    }
  }

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
