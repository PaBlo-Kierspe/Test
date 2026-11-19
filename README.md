# Kassenbuch – Einnahmen, Ausgaben & Ersparnisse fürs iPhone

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
