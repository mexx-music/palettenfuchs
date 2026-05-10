# Manuelle Paletten-Justierung - Phase 1

## Überblick
Diese Phase führt die Grundlagen für die manuelle Palettenplatzierung ein.

## Implementierte Features

### 1. Palette Auswahl (✅ Fertig)
- **Tap auf Palette**: Markiert/demarkiert eine einzelne Palette
- **Visuelle Markierung**: Rote Rand-Linie um ausgewählte Paletten
- **Mehrfachauswahl**: Beliebig viele Paletten können gleichzeitig ausgewählt werden
- **Reihen-erkennung**: Der Klick findet automatisch die richtige Reihe

### 2. Action-Menü (✅ Fertig)
- **Long-Press auf Palette**: Öffnet ein Kontextmenü mit Aktionen
- **Aktionen** (alle lokalisiert):
  - "Vorne verschieben" - Reihe nach vorne tauschen
  - "Hinten verschieben" - Reihe nach hinten tauschen
  - "Drehen" - Euro-Palette quer/längs wechseln
  - "Auswahl löschen" - Alle Markierungen entfernen
- **Intelligentes Deaktivieren**: Buttons sind grau/disabled, wenn nicht möglich

### 3. Verschieben (Basis) (✅ Fertig)
- Reihen tauschen mit Nachbar-Reihe (schrittweise)
- "Nach vorne" = tauscht mit vorheriger Reihe
- "Nach hinten" = tauscht mit nächster Reihe
- Noch kein freies Drag-and-Drop

### 4. Drehen - Validierung (✅ Vorbereitet)
- `ManualPalletService.tryRotatePallet()` prüft:
  - Ist es eine Euro-Palette?
  - Passt die neue Rotation in den Trailer?
  - Gibt Fehlertext zurück

### 5. Modelle für späteren Ausbau (✅ Vorbereitet)

#### `ManualLoadSeed` (erweitert)
- `selectedPalletIds`: Verfolgt ausgewählte Paletten
- `lastModified`: Timestamp der letzten Änderung
- Methoden: `togglePalletSelection()`, `clearSelection()`

#### `PlacedPallet` (neu)
- Repräsentiert eine einzelne Palette
- Eigenschaften: ID, Reihen-Index, Position in Reihe
- Geometrie-Informationen

#### `SavedLoadPattern` (neu - für Learning)
- `id`, `name`, `trailerType`
- `euroCount`, `industryCount`, `kgPerEuro`, `kgPerIndustry`
- `patternRows`: Die Reihen des Musters
- `createdAt`, `lastUsedAt`
- Bereit für Muster-Speicherung

### 6. Services (✅ Fertig)

#### `ManualPalletService`
- `extractPlacedPallets()`: Generiert eindeutige Palette-IDs
- `findPalletAtPosition()`: Hit-Test für Tap
- `calculatePalletScreenRect()`: Konvertiert cm-Koordinaten zu Bildschirm-Pixeln
- `moveRowForward/Backward()`: Reihen-Tausch
- `tryRotatePallet()`: Validiert Rotation mit Größen-Prüfung

## Technische Details

### Palette-ID Format
```
"{rowIndex}_{palletIndexInRow}"
Beispiel: "0_0" = erste Palette der ersten Reihe
```

### Highlighting
```dart
// Im TrailerPainter
if (isSelected) {
  canvas.drawRect(rect, Paint()..color = Colors.red..strokeWidth = 3.0);
}
```

### Lokalisierung
Alle Menü-Texte verwenden `AppStrings.get()`:
- Deutsch (DE)
- Englisch (EN)
- Serbisch (SR)

## Nächste Phasen (geplant)

### Phase 2: Echtes Drag-and-Drop
- Finger-Bewegung tracking
- Visuelle Feedback während des Ziehens
- Drop-Validierung

### Phase 3: Muster-Speicherung
- SavedLoadPattern speichern/laden
- Muster-Verwaltungs-UI
- "Favoriten" Funktionalität

### Phase 4: Auto-Complete
- Nach manuellen Änderungen
- Engine füllt freien Platz automatisch

### Phase 5: Learning
- Häufig verwendete Muster erkennen
- Suggestions beim neuen Ladeplan

## Testing-Tipps

1. **Palette tippen**: Sollte rote Markierung zeigen
2. **Mehrfach tippen**: Markierung toggle-n
3. **Long-Press**: Menü erscheint
4. **Verschieben**: Reihen tauschen Position
5. **Drehen**: Nur bei Euro-Paletten, mit Validierung
6. **Sprache wechseln**: Labels ändern sich

## Dateistruktur

```
models/
  - placed_pallet.dart (neu)
  - manual_load_seed.dart (erweitert)
  - saved_load_pattern.dart (neu)

logic/
  - manual_pallet_service.dart (neu)

presentation/widgets/
  - trailer_load_view.dart (erweitert)
  - trailer_painter.dart (erweitert)
  - pallet_action_menu.dart (neu)
```

## Code Quality
- ✅ `flutter analyze` clean (nur 1-2 Minor Warnings)
- ✅ Keine zusätzlichen Packages
- ✅ Keine Engine-Änderungen
- ✅ Vollständig lokalisiert
