# Note di sviluppo

Documento di stato per riprendere il progetto in qualsiasi momento.

## Configurazione Azure AD

| Campo | Valore |
|---|---|
| Tenant | intrawelt.com |
| Tenant ID | 5f7f1a52-302a-4d90-a9c6-d89cc40f133b |
| App | TeamsExporter |
| Client ID | 3c10bf5a-615c-4e83-b27d-9c894262de52 |
| Secret | in config.local.json (scadenza ~giugno 2028) |

Permessi Application concessi: Channel.ReadBasic.All, ChannelMessage.Read.All, Chat.Read.All, Team.ReadBasic.All, User.Read.All

## Struttura file

```
C:\Scripts\export-teams-chat\
  Export-TeamsMessages.ps1   script principale
  Get-TeamsIds.ps1            utility scoperta ID
  config.json                 template (committato)
  config.local.json           valori reali (gitignored)
  README.md                   documentazione utente
  SVILUPPO.md                 questo file
  output/                     export generati (gitignored)
    media/                    immagini inline scaricate
    teams_*.csv               messaggi
    teams_*_stats.csv         statistiche
    checkpoint.json           stato run interrotta
```

## Repository

`git@github-corp:asopranzi-intrawelt/export-teams-chat.git`
Branch principale: main

## Test eseguiti

| Data | Comando | Risultato |
|---|---|---|
| 2026-06-18 | Get-TeamsIds -What Teams | OK - 18 team trovati |
| 2026-06-18 | Get-TeamsIds -What Channels (team IT) | OK - 1 canale "General" |
| 2026-06-18 | Export Channel IT General, nessun filtro | OK - 126 msg (2019-2021, legacy Skype) |
| 2026-06-18 | Export Channel Sviluppo SaaS, StartDate 2025-01-01 | OK - 327 msg (18 root + 309 reply, Nov-Dic 2025) |
| 2026-06-18 | Export Channel Sviluppo SaaS, StartDate 2025-01-01 (con nomi utente) | OK - 5 utenti identificati |
| 2026-06-18 | Export Chat 1:1 Alessio-Tommaso, filtro utente + date con orario + DownloadMedia | OK - 45 msg (Feb 11 12:22 -> Feb 18 13:17), 3271 totali in chat, throttling gestito |

## Bug risolti

| Problema | Causa | Fix |
|---|---|---|
| "Elemento pipe vuoto non consentito" | PS 5.1 non supporta pipe da switch | Variabile intermedia $raw |
| "Impossibile trovare proprieta Count" | Set-StrictMode -Version Latest con proprieta dinamiche Graph API | Rimosso Set-StrictMode |
| checkpoint.json non trovato | cartella output/ non ancora creata | New-Item in Save-Checkpoint prima di scrivere |
| Campo UPN sempre vuoto | Graph API non include userPrincipalName in chatMessage.from.user | Rinominato in UserId, usa .id (Object ID) |
| canali @thread.skype senza nome utente | messaggi Skype migrati non hanno from.user | Fallback a "(sistema)" |
| Get-TeamsIds -What Channels 403 | mancava Channel.ReadBasic.All | Aggiunto permesso e consent |
| Retry 429 mostrava sempre "tentativo 1/5" | $_.Exception.Response perso tra tentativi, Retry-After parsava a 0 | try/catch separato su status e header, backoff minimo max(Retry-After, 2^attempt*5) |
| 404 su /replies in chat 1:1 | endpoint replies non supportato per chat private | catch 404 silenzioso nel fetch risposte |
| ChatId troncato in Get-TeamsIds -What Chats | Format-Table taglia valori lunghi | Output con Write-Host su riga separata per ogni chat |

## Patch applicate (sessione 2026-06-19)

| Patch | Descrizione |
|---|---|
| #2 | Throttling preventivo: Start-Sleep 300ms tra pagine in Invoke-GraphPaged |
| #3 | Get-TeamsIds -What Chats -Quick: salta fetch membri per velocità |
| #4 | Get-MediaLinks: Write-Verbose del raw HTML (primi 300 char) per debug URL hostedContents |
| #5 | Resolve-UserId con cache $script:userCache; campo UserId rinominato in UPN |

## Funzionalita implementate

- [x] Export da Chat privata (Mode=Chat)
- [x] Export da Canale Teams (Mode=Channel)
- [x] Export tutte le chat di un utente (Mode=UserChats)
- [x] Filtro mittenti: OR tra lista, accetta displayName/UPN/ObjectID
- [x] Filtro date con componente orario (StartDate/EndDate)
- [x] Filtro keyword: OR (default) o AND, modalita Insensitive/Exact/Regex/Word
- [x] Filtro @mention
- [x] Filtro messaggi modificati (OnlyEdited)
- [x] Filtro importanza (Importance)
- [x] Filtro solo allegati (OnlyWithAttachments)
- [x] Esclusione bot/app (NoBots)
- [x] Keyword highlight nel testo con [[keyword]]
- [x] Thread replies sempre incluse
- [x] Statistiche per utente/giorno/keyword su file separato
- [x] Checkpoint + Resume (salta sorgenti gia elaborate)
- [x] Delta token per export incrementale
- [x] Retry automatico su 429/503 con backoff esponenziale
- [x] Output CSV e JSON
- [x] AttachmentUrls nel record (URL allegati file)
- [x] DownloadMedia: scarica immagini inline (hostedContents) in output/media/
- [x] Throttling preventivo 300ms tra pagine (riduce 429 su chat grandi)
- [x] Get-TeamsIds -Quick: skip fetch membri per Chats
- [x] UPN risolto via GET /users/{id} con cache (campo UPN nel CSV)

## Comandi utili

```powershell
# Verifica rapida contenuto export (apre griglia interattiva)
Import-Csv "C:\Scripts\export-teams-chat\output\<file>.csv" | Out-GridView

# Lista team disponibili
.\Get-TeamsIds.ps1 -What Teams

# Lista canali di un team
.\Get-TeamsIds.ps1 -What Channels -TeamId "<guid>"

# Lista chat di un utente con partecipanti
.\Get-TeamsIds.ps1 -What Chats -UserId "utente@intrawelt.com"

# Export base canale
.\Export-TeamsMessages.ps1 -Mode Channel -TeamId "<guid>" -ChannelId "<id>" -StartDate "2026-01-01"

# Export chat 1:1 con filtro utente, finestra temporale precisa, download media
.\Export-TeamsMessages.ps1 -Mode Chat -ChatId "<id>" -Users "Nome Cognome" -StartDate "2026-02-11 12:22" -EndDate "2026-02-18 13:17" -DownloadMedia
```

## Note tecniche Graph API

- Canali: GET /teams/{id}/channels/{id}/messages?$top=50
- Chat: GET /chats/{id}/messages?$top=50
- Risposte: GET .../messages/{id}/replies?$top=50
- Media inline: GET .../messages/{id}/hostedContents/{contentId}/$value (binario)
- Chat members: GET /chats/{id}/members
- messageType filtra solo "message" (esclude systemEventMessage, chatEvent, unknownFutureValue)
- @odata.nextLink per paginazione, @odata.deltaLink per delta token
- Token: client_credentials flow, scade ~3600s, auto-refresh implementato
- Inline images nel body HTML: src="https://graph.microsoft.com/.../hostedContents/.../$value"
- Allegati file: $msg.attachments[].contentUrl (OneDrive/SharePoint link, non scaricabile senza Sites.Read.All)
