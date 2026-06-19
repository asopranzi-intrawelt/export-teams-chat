# Stato progetto — export-teams-chat

Questo documento serve a riprendere il progetto in una nuova sessione di Claude Code.
Leggilo per intero prima di toccare qualsiasi file.

---

## Cos'è

Script PowerShell per esportare messaggi da Microsoft Teams via Microsoft Graph API.
Tenant: intrawelt.com. Usato per audit, analisi e ricerca messaggi specifici.
Repo: `git@github-corp:asopranzi-intrawelt/export-teams-chat.git`

---

## File rilevanti

```
Export-TeamsMessages.ps1   script principale — tutto il lavoro sta qui
Get-TeamsIds.ps1            utility per scoprire TeamId, ChannelId, ChatId
config.json                 template (placeholder, committato)
config.local.json           valori reali Azure AD (gitignored, non toccare)
output/                     export generati (gitignored)
  media/                    immagini inline scaricate con -DownloadMedia
SVILUPPO.md                 log completo di test, bug e note tecniche
```

---

## Configurazione Azure AD (non cambiare)

- Tenant ID: `5f7f1a52-302a-4d90-a9c6-d89cc40f133b`
- Client ID: `3c10bf5a-615c-4e83-b27d-9c894262de52`
- Secret: in `config.local.json` (scade ~giugno 2028)
- Permessi Application concessi: `Channel.ReadBasic.All`, `ChannelMessage.Read.All`, `Chat.Read.All`, `Team.ReadBasic.All`, `User.Read.All`

---

## Cosa funziona (testato)

- Export da canale Teams con filtro data, keyword, utente
- Export da chat 1:1 con filtro mittente e finestra temporale con orario (es. `"2026-02-11 12:22"`)
- Thread replies incluse nei canali (non nelle chat 1:1, endpoint non supportato — già gestito)
- Throttling 429 con retry e backoff esponenziale
- Download immagini inline (`-DownloadMedia`) via endpoint `/hostedContents`
- Campo `AttachmentUrls` con URL allegati file
- Statistiche su file separato `_stats.csv`
- Checkpoint + Resume + delta token per export incrementale
- `Get-TeamsIds.ps1 -What Chats` mostra partecipanti delle chat 1:1

---

## Patch pendenti / cose da fare

Queste sono le modifiche concrete da applicare al codice. Ognuna è indipendente dalle altre salvo dove indicato.

### 1. Validare il download media su messaggi con immagini reali

Il flag `-DownloadMedia` è implementato in `Get-MediaLinks` (cerca la funzione in `Export-TeamsMessages.ps1`).
Usa regex `src="(https://[^"]+/hostedContents/[^"]+/\$value)"` sul body HTML del messaggio.
Non è ancora stato testato su messaggi che contengono effettivamente immagini incollate.
Verificare che:
- il percorso file venga scritto correttamente nel campo `MediaFiles` del CSV
- il file venga salvato in `output/media/` con estensione corretta
- la chiamata `Invoke-WebRequest` con il token Graph funzioni sul binary content

### 2. Throttling troppo aggressivo sulle chat con molti messaggi

La chat Alessio-Tommaso ha 3271 messaggi. Durante il fetch vengono fatti 65+ chiamate paginate (50 msg/pagina).
Su ogni pagina si riceve 429 e si attende 10s. Totale: ~10-11 minuti solo per la paginazione.
Soluzione da valutare: aggiungere un `Start-Sleep -Milliseconds 300` tra una pagina e l'altra dentro `Invoke-GraphPaged`
per evitare il throttling preventivamente invece di reagirvi. Testare che non rallenti troppo i casi piccoli.
La funzione da modificare è `Invoke-GraphPaged` in `Export-TeamsMessages.ps1`.

### 3. Get-TeamsIds -What Chats è lento su account con molte chat

Per ogni chat 1:1 viene fatto un API call separato a `/chats/{id}/members`.
Con 150+ chat (caso Alessio) questo genera 50+ chiamate aggiuntive e può anch'esso incontrare throttling.
Soluzione: aggiungere un parametro `-Quick` che salta il fetch dei membri e mostra solo Tipo + ChatId,
oppure fare il fetch membri solo se l'utente passa `-ShowMembers`.
Il codice da modificare è nel blocco `"Chats"` di `Get-TeamsIds.ps1`.

### 4. Campo MediaFiles rimane vuoto anche quando ci sono allegati immagine

Da verificare: quando un utente incolla un'immagine in Teams (non la allega come file),
il body HTML del messaggio contiene un tag `<img src="...hostedContents...">`.
Se il campo `MediaFiles` è vuoto dopo un export con `-DownloadMedia`, potrebbe essere che:
- l'immagine è un allegato file (appare in `Allegati` / `AttachmentUrls`) non un hosted content
- il pattern regex non matcha la variante di URL usata da quel tenant
Loggare il raw HTML del primo messaggio per confrontare il formato attuale dell'URL.

### 5. Il campo UserId nel CSV non è human-readable

Attualmente `UserId` contiene l'Object ID di Azure AD (es. `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
Sarebbe più utile mostrare la UPN (email) che però non è inclusa nel payload `chatMessage.from.user`.
Per ottenerla serve una chiamata aggiuntiva a `GET /users/{id}` e cachearla (stessa UPN per ogni messaggio dello stesso utente).
Implementare una cache dizionario `$script:userCache = @{}` e una funzione `Resolve-UserId` che:
- controlla la cache prima di chiamare l'API
- chiama `GET /users/{userId}?$select=userPrincipalName,displayName`
- salva il risultato in cache
Aggiornare `ConvertTo-Record` per usare `Resolve-UserId` e popolare `UPN` (rinominare `UserId` → `UPN` di nuovo).

---

## Come testare dopo una patch

```powershell
cd C:\Scripts\export-teams-chat

# Test base (canale attivo)
.\Export-TeamsMessages.ps1 -Mode Channel -TeamId "0fbbcb60-ff4e-4d9c-8a02-f852c86ec649" -ChannelId "19:OXSAaqRNo9_Cuh8AGD_3CxUQqUGnHz0Lpbl9JuWwZnE1@thread.tacv2" -StartDate "2025-01-01"

# Test chat 1:1 con filtro temporale preciso
.\Export-TeamsMessages.ps1 -Mode Chat -ChatId "19:877ead0a-34c9-46e4-8510-08ccde6ebe1a_fb020a89-981d-4e25-a543-9a83c34624bc@unq.gbl.spaces" -Users "Alessio Sopranzi - Intrawelt" -StartDate "2026-02-11 12:22" -EndDate "2026-02-18 13:17" -DownloadMedia

# Verifica risultato
Import-Csv "C:\Scripts\export-teams-chat\output\<ultimo file>.csv" | Out-GridView
```

Risultati attesi test canale: ~327 messaggi, 5 utenti, date Nov-Dic 2025.
Risultati attesi test chat: 45 messaggi, solo Alessio Sopranzi, date Feb 2026.

---

## Nota sull'ambiente

- PowerShell 5.1 (Windows PowerShell, non Core) — alcune sintassi PS 7 non funzionano
- `Set-StrictMode` rimosso perché incompatibile con le proprietà dinamiche delle risposte Graph API
- Il repo usa l'identità SSH `github-corp` per il push
