# export-teams-chat

Script PowerShell per esportare messaggi da Microsoft Teams via Microsoft Graph API.
Tutti i filtri sono combinabili tra loro.

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
.\Get-TeamsIds.ps1 -What Chats -UserId "utente@dominio.com"
```

### Export-TeamsMessages.ps1

```powershell
# Export canale con filtro data
.\Export-TeamsMessages.ps1 -Mode Channel `
    -TeamId "guid" `
    -ChannelId "19:..." `
    -StartDate "2026-01-01"

# Chat privata: messaggi di un utente in una finestra precisa
.\Export-TeamsMessages.ps1 -Mode Chat `
    -ChatId "19:..." `
    -Users "Nome Cognome" `
    -StartDate "2026-02-11 12:22" `
    -EndDate "2026-02-18 13:17" `
    -DownloadMedia

# Tutte le chat di un utente, con keyword
.\Export-TeamsMessages.ps1 -Mode UserChats `
    -UserId "utente@dominio.com" `
    -Keywords "parola1,parola2" `
    -MatchMode Insensitive

# Riprende export interrotto (usa delta token)
.\Export-TeamsMessages.ps1 -Mode UserChats -UserId "..." -Resume
```

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

- La paginazione recupera 50 messaggi per chiamata API, senza limite al totale.
- Le risposte nei thread sono sempre incluse.
- I canali migrati da Skype for Business (`@thread.skype`) non espongono il nome utente via API.
- Il `-Resume` salva un delta token dopo ogni sorgente completata. Le run successive con `-Resume` recuperano solo i messaggi nuovi o modificati.
- Il token OAuth2 viene rinnovato automaticamente prima della scadenza.
- Su errori 429/503 (throttling API) lo script attende con backoff esponenziale e riprova fino a 5 volte.
