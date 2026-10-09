# export-teams-chat

Script PowerShell per esportare messaggi da Microsoft Teams via Microsoft Graph API. Tutti i filtri sono combinabili tra loro.

## Export di una conversazione diretta

Per acquisizione con verbale, archivio tecnico, manifesti SHA-256 e consegna verificata usare [Export-TeamsEvidence.ps1](Export-TeamsEvidence.ps1). Procedura e limiti sono in [docs/teams-evidence.md](docs/teams-evidence.md). Il tool raccoglie la consegna in cinque file e restituisce anche l'impronta del manifesto da conservare separatamente.

Per una nuova estrazione tra due persone usare `Export-TeamsConversation.ps1`. Conserva il botta e risposta con autore, testo, timestamp UTC e ora italiana con offset, in ordine cronologico crescente. Seleziona le sole chat dirette con i due partecipanti e il periodo espressamente approvato; produce HTML leggibile e stampabile, TXT, CSV, copia tecnica dei messaggi, riepilogo e SHA-256. Non scarica allegati o immagini.

Il percorso ordinario richiede il [fascicolo firmato](docs/Fascicolo-export.template.txt) e la verifica dei [presupposti privacy](docs/privacy-export.md). Copiare `export-request.example.json` in `_notes/export-request.local.json`, mantenendolo in `Draft` finché la verifica non è completata. Il parametro `-ExecutionInstructionPath` gestisce un ordine esplicito di procedere prima della firma: richiede un'istruzione separata con stato `ExecuteBeforeSignature`, testo dell'ordine, registrazione temporale e hash del Word e della richiesta. Registra l'assenza di firma e non dichiara una verifica giuridica. Il parametro `-EvidencePath` conserva risposte Graph e registro delle richieste, senza credenziali.

```powershell
.\Export-TeamsConversation.ps1 -RequestPath .\_notes\export-request.local.json
```

Senza istruzione separata lo script si ferma prima delle credenziali se la richiesta è incompleta o in bozza. `StartDate` è inclusivo e `EndDateExclusive` esclusivo; entrambi devono includere il fuso, per esempio `2025-01-01T00:00:00+01:00` e `2026-01-01T00:00:00+01:00`. I nomi si risolvono anche se in directory sono scritti cognome-nome; le omonimie interrompono l'operazione.

Per verificare il nuovo percorso senza accedere a Teams:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-TeamsConversation.ps1
```

Il sistema di istruzioni e memoria è indicizzato da `CLAUDE.md` e `AGENTS.md`. Configurazione compilata, autorizzazioni, nomi e output restano nelle cartelle private ignorate da git. Questa esclusione non cifra i file né verifica i permessi di accesso.

## Requisiti

- PowerShell 5.1+
- Account admin Microsoft 365
- App registrata su Azure AD (vedi Setup)

## Setup

### 1. Registrazione app Azure AD

Nel portale Entra ID: App registrations > New registration
- Tipo account: single tenant
- Nessun redirect URI

Aggiungere questi permessi **Application** (non Delegated) e fare grant admin consent:

| Permesso | Uso |
|---|---|
| Channel.ReadBasic.All | Listare canali |
| ChannelMessage.Read.All | Leggere messaggi nei canali |
| Chat.Read.All | Leggere chat private e scaricare media inline |
| Team.ReadBasic.All | Listare team |
| User.Read.All | Risolvere info utenti |

Creare un client secret e copiarne il valore.

### 2. Configurazione

Creare `config.local.json` (gitignored) con:

```json
{
    "TenantId":     "tenant-id",
    "ClientId":     "app-client-id",
    "ClientSecret": "secret-value"
}
```

`config.json` nel repo contiene solo placeholder e serve da template.

## Script

### Get-TeamsIds.ps1

Recupera gli ID necessari per l'export.

```powershell
# Lista tutti i team
.\Get-TeamsIds.ps1 -What Teams

# Lista canali di un team
.\Get-TeamsIds.ps1 -What Channels -TeamId "guid"

# Lista chat di un utente (mostra partecipanti per chat 1:1)
.\Get-TeamsIds.ps1 -What Chats -UserId "<utente>@<dominio>"

# Lista veloce senza fetch partecipanti (utile su account con molte chat)
.\Get-TeamsIds.ps1 -What Chats -UserId "<utente>@<dominio>" -Quick
```

### Export-TeamsMessages.ps1

```powershell
# Export canale con filtro data
.\Export-TeamsMessages.ps1 -Mode Channel  -TeamId "guid"  -ChannelId "19:..."  -StartDate "2026-01-01"

# Chat privata: messaggi di un utente in una finestra precisa
.\Export-TeamsMessages.ps1 -Mode Chat  -ChatId "19:..."  -Users "Nome Cognome"  -StartDate "2026-02-11 12:22"  -EndDate "2026-02-18 13:17"  -DownloadMedia

# Tutte le chat di un utente, con keyword
.\Export-TeamsMessages.ps1 -Mode UserChats  -UserId "<utente>@<dominio>"  -Keywords "parola1,parola2"  -MatchMode Insensitive

# Riprende export interrotto (usa delta token)
.\Export-TeamsMessages.ps1 -Mode UserChats -UserId "..." -Resume
```

### ConvertTo-Docx.ps1

Converte un CSV di export in un documento Word con le immagini inline incorporate. Richiede Microsoft Word installato (automazione COM).

```powershell
.\ConvertTo-Docx.ps1 -CsvPath ".\output\teams_chat_20260728_174921.csv"  -DocxPath ".\output\Chat.docx"  -Title "Messaggi di Nome Cognome"  -Subtitle "28/07/2026, dalle 12:49 all'ultimo messaggio"
```

| Parametro | Descrizione |
|---|---|
| `-CsvPath` | CSV prodotto da `Export-TeamsMessages.ps1`. Obbligatorio |
| `-DocxPath` | Percorso del .docx. Default: stesso nome del CSV con estensione `.docx` |
| `-MediaPath` | Cartella immagini. Default: `media/` accanto al CSV |
| `-Title` | Titolo in prima pagina |
| `-Subtitle` | Riga descrittiva sotto il titolo |
| `-MaxImageWidthPt` | Larghezza massima immagini in punti. Default: larghezza utile pagina |

I messaggi vengono ordinati in senso cronologico crescente e le date convertite in ora locale (il CSV le contiene in UTC). Le immagini elencate in `MediaFiles` sono inserite dopo il testo del messaggio, con il nome file come didascalia. Gli allegati file non inline compaiono come riferimento testuale con il relativo URL.

## Parametri

| Parametro | Descrizione |
|---|---|
| `-Mode` | `Chat`, `Channel`, `UserChats` |
| `-ChatId` | ID chat privata |
| `-TeamId` | GUID del team |
| `-ChannelId` | ID canale |
| `-UserId` | UPN o Object ID utente (per UserChats o come sorgente) |
| `-Users` | Filtro mittenti, separati da virgola, logica OR. Accetta displayName, UPN, Object ID |
| `-StartDate` | Data/ora inizio (inclusiva). Es: "2026-02-11 12:22" |
| `-EndDate` | Data/ora fine (inclusiva). Es: "2026-02-18 13:17" |
| `-Keywords` | Keyword, separati da virgola, logica OR |
| `-KeywordAnd` | Rende le keyword AND |
| `-MatchMode` | `Insensitive` (default), `Exact`, `Regex`, `Word` |
| `-MentionedUser` | Solo messaggi con @mention a quell'utente |
| `-OnlyEdited` | Solo messaggi modificati dopo l'invio |
| `-Importance` | `Normal`, `High`, `Urgent` |
| `-OnlyWithAttachments` | Solo messaggi con allegati |
| `-NoBots` | Esclude messaggi di bot/app |
| `-DownloadMedia` | Scarica immagini inline nella cartella output/media/ |
| `-OutputFormat` | `CSV` (default), `JSON` |
| `-Resume` | Riprende dal checkpoint, usa delta token per export incrementale |

## Get-TeamsIds parametri aggiuntivi

| Parametro | Descrizione |
|---|---|
| `-Quick` | (solo `-What Chats`) Salta il fetch dei partecipanti, mostra solo tipo e ChatId. Utile su account con molte chat dove il fetch per ognuna genera throttling. |

## Logica filtri

I filtri di tipo diverso si combinano in AND. All'interno dello stesso tipo:

| Filtro | Logica interna |
|---|---|
| `-Users` | OR tra i mittenti |
| `-Keywords` | OR (default), AND con `-KeywordAnd` |

## Output

Ogni export produce in `output/`:
- `teams_{mode}_{timestamp}.csv` - messaggi
- `teams_{mode}_{timestamp}_stats.csv` - conteggi per utente, giorno, keyword

Con `-DownloadMedia`, le immagini inline vengono salvate in `output/media/` e il percorso locale appare nel campo `MediaFiles` del CSV.

Il campo `AttachmentUrls` contiene gli URL degli allegati file (OneDrive/SharePoint).

## Note

- La paginazione recupera 50 messaggi per chiamata API, senza limite al totale. Tra una pagina e l'altra è presente una pausa preventiva di 300ms per ridurre il rischio di throttling.
- Le risposte nei thread sono sempre incluse.
- Il campo `UPN` contiene la User Principal Name (email) del mittente, risolta tramite una chiamata a `GET /users/{id}` con cache per evitare chiamate duplicate per lo stesso utente.
- I canali migrati da Skype for Business (`@thread.skype`) non espongono il nome utente via API.
- Il `-Resume` salva un delta token dopo ogni sorgente completata. Le run successive con `-Resume` recuperano solo i messaggi nuovi o modificati.
- Il token OAuth2 viene rinnovato automaticamente prima della scadenza.
- Su errori 429/503 (throttling API) lo script attende con backoff esponenziale e riprova fino a 5 volte.
