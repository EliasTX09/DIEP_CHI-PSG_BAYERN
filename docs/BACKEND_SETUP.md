# Backend-Einrichtung (Supabase)

Ohne Backend laeuft das Spiel **offline** (Bots, Ghost-Challenge mit eigenem Geist, lokaler Speicherstand).
Fuer Accounts, Freunde, Lobbys und Echtzeit-Multiplayer brauchst du ein (kostenloses) Supabase-Projekt.

## 1. Projekt anlegen
1. <https://supabase.com> -> *New project* (Region in deiner Naehe).
2. **Project Settings -> API**: kopiere die **Project URL** und den **anon public key**.
   Den `service_role`-Key niemals in die App oder ins Repo!

## 2. Auth konfigurieren
**Authentication -> Providers**
- *Email* aktiviert lassen. Zum schnellen Testen unter *Authentication -> Sign In / Providers -> Email* "Confirm email" ausschalten.
- **Allow anonymous sign-ins** einschalten (= Gast-Modus). Spaeter wird der Gast per
  "Gast-Account verknuepfen" zu einem E-Mail-Account (gleiche User-ID, Fortschritt bleibt).

## 3. Datenbank
**SQL Editor -> New query**: Inhalt von [`backend/schema.sql`](../backend/schema.sql) einfuegen und ausfuehren.
Das legt `profiles`, `friendships`, `invites`, `ghosts` inkl. Row-Level-Security an.

## 4. Realtime
Der Multiplayer nutzt **Realtime Broadcast + Presence** (keine Tabellen noetig). Unter
*Realtime -> Settings* sicherstellen, dass Realtime aktiv ist und *Allow public access* an ist
(Prototyp; fuer Produktion private Channels mit `realtime.messages`-Policies verwenden).

## 5. Zugangsdaten ins Spiel
Lokal:
```bash
cp minigolf/config/backend.example.cfg minigolf/config/backend.cfg
# URL und anon_key eintragen – die Datei ist in .gitignore
```
GitHub Actions (APK mit Backend): Repo -> *Settings -> Secrets and variables -> Actions* ->
`SUPABASE_URL` und `SUPABASE_ANON_KEY` anlegen. Der Workflow schreibt daraus beim Build `config/backend.cfg`.
(Der anon key ist fuer Clients gedacht – Sicherheit kommt von RLS, nicht vom Verstecken des Keys.)

## 6. Testen
1. App starten -> *Account* -> *Als Gast spielen*. In *Table Editor -> profiles* muss eine Zeile erscheinen.
2. Zwei Geraete/Instanzen: Beide per Gast anmelden, einer erstellt in der *Lobby* einen Raum, der andere
   tritt mit dem Code bei -> Host startet das Match.
3. Freunde: Benutzernamen eintragen (im Account-Menue aenderbar) -> Anfrage -> Gegenseite "Annehmen" -> "Einladen".

## Datenfluss
| Zweck | Weg |
|---|---|
| Login, Gast, Upgrade | `Supa` (GoTrue REST) |
| Profil, Freunde, Einladungen, Ghosts | `Supa` (PostgREST) |
| Positionen/Schuesse live | `Net` (Realtime WebSocket, Broadcast ~10 Hz) |

## Bekannte Grenzen
- **Realtime-Protokoll ungetestet gegen ein Live-Projekt** (`NetworkManager.gd` ist die einzige Datei, die das kennt).
- Jeder Client simuliert seinen eigenen Ball; Gegner werden interpoliert (kein Server-Authority) -> cheatbar.
- Coins/Upgrades werden clientseitig vergeben (siehe Hinweis am Ende von `schema.sql`).
