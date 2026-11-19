# Kassenbuch – Einnahmen, Ausgaben & Ersparnisse fürs iPhone

Das Repository enthält zwei Versionen:

| | Native iPhone-App (`ios/`) | Web-App (`index.html`) |
|---|---|---|
| Technik | Swift, SwiftUI, SwiftData, Swift Charts | HTML/JS, als PWA installierbar |
| Installation | Xcode (Mac) oder Sideloading | Safari → „Zum Home-Bildschirm“ |
| Face-ID-Sperre | ja | nein |
| Backups | gleiches Format, gegenseitig ladbar | |

## Native iPhone-App installieren

**Mit Mac (empfohlen, kostenlos):**
1. Xcode 16 oder neuer aus dem App Store installieren.
2. `ios/Kassenbuch.xcodeproj` öffnen.
3. Links das Projekt *Kassenbuch* → *Signing & Capabilities* → bei *Team* deine Apple-ID wählen
   (ggf. *Bundle Identifier* ändern, z. B. `de.deinname.kassenbuch`).
4. iPhone per Kabel anschließen, oben als Ziel auswählen und auf ▶︎ klicken.
5. Auf dem iPhone: *Einstellungen → Allgemein → VPN & Geräteverwaltung* → Entwickler vertrauen.
   Ab iOS 16 zusätzlich *Einstellungen → Datenschutz & Sicherheit → Entwicklermodus* einschalten.

Mit einer kostenlosen Apple-ID läuft die App 7 Tage und muss dann erneut über Xcode installiert
werden. Mit dem Apple Developer Program (99 €/Jahr) gilt sie ein Jahr, und du kannst sie über
TestFlight oder den App Store verteilen.

**Ohne Mac:** Der GitHub-Workflow *iOS-App bauen* erzeugt bei jedem Push eine unsignierte
`Kassenbuch-unsigniert.ipa` (unter *Actions → Lauf → Artifacts*). Diese kannst du z. B. mit
Sideloadly (Windows/Mac) oder AltStore mit deiner Apple-ID signieren und aufs iPhone laden.

### Funktionen der nativen App
- Alles aus der Web-Version (Übersicht, Buchungen, Jahr, Sparen mit Sparzielen und
  voraussichtlichem Datum, monatliche Buchungen, CSV-Export, Backups)
- Native Diagramme (Swift Charts), Suche über alle Buchungen, Wischen zum Löschen
- Sperre mit Face ID / Touch ID / Code, Inhalt im App-Umschalter verborgen
- Hell- und Dunkelmodus, Backups der Web-Version lassen sich importieren

---

# Web-App (PWA)

Eine iPhone-App (Web-App/PWA), mit der du alle Einnahmen und Ausgaben übersichtlich erfasst –
inklusive **Zinsen, Mieteinnahmen und Dividenden** (passives Einkommen) und einer eigenen
Spalte für **Ersparnisse**.

## Funktionen

- **Übersicht pro Monat**: frei verfügbarer Betrag, Sparquote, Aufteilung der Einnahmen
  (Ausgaben / Gespart / Übrig), Vergleich zum Vormonat
- **Passives Einkommen**: Zinsen, Mieteinnahmen und Dividenden einzeln, mit Anteil an den Einnahmen
  und Jahressumme
- **Ausgaben nach Kategorie** als Ringdiagramm, **letzte 6 Monate** als Balkendiagramm
- **Buchungen**: Liste nach Tagen, Filter (Einnahmen, Zinsen·Mieten·Dividenden, Ausgaben, Ersparnisse),
  Antippen zum Bearbeiten oder Löschen
- **Jahr**: Tabelle mit den Spalten Einnahmen · davon passiv · Ausgaben · **Ersparnisse** · Saldo
- **Sparen**: Sparguthaben mit Verlauf über 12 Monate und **beliebig viele Sparziele** – jeweils mit Fortschritt, **voraussichtlichem Datum bis zum Erreichen** und optionalem Wunschtermin („Im Plan“ / nötige Sparrate pro Monat)
- **Monatliche Buchungen** (Gehalt, Miete, Sparplan …) werden automatisch jeden Monat angelegt
- **Backup** als Datei sichern/laden, Export als CSV für Excel/Numbers
- Hell- und Dunkelmodus, funktioniert offline, Daten bleiben nur auf dem Gerät

## Auf dem iPhone installieren

Die App muss einmal über eine HTTPS-Adresse erreichbar sein, z. B. mit **GitHub Pages**:

1. Auf GitHub im Repository: *Settings → Pages → Branch* auswählen (z. B. `main`, Ordner `/root`) → *Save*.
2. Die angezeigte Adresse (`https://<name>.github.io/<repo>/`) in **Safari** auf dem iPhone öffnen.
3. Auf **Teilen** tippen → **Zum Home-Bildschirm** → *Hinzufügen*.

Danach startet „Kassenbuch“ wie eine normale App im Vollbild, auch ohne Internet.

> Die Daten werden lokal auf dem iPhone gespeichert. Unter *Mehr → Backup sichern* kannst du sie
> regelmäßig als Datei (z. B. in iCloud Drive) ablegen.

## Dateien

- `index.html` – die komplette App (HTML, CSS, JavaScript, keine Abhängigkeiten)
- `manifest.webmanifest`, `sw.js` – Installation als App und Offline-Betrieb
- `icons/` – App-Icons
