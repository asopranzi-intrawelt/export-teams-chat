<#
.SYNOPSIS
    Estrae messaggi da Microsoft Teams tramite Microsoft Graph API.
    Tutti i filtri sono combinabili tra loro (AND tra tipi diversi).

.PREREQUISITI
    Vedere Get-TeamsIds.ps1 per recuperare ChatId, TeamId, ChannelId.
    Vedere config.json per la configurazione dell'app Azure AD.

.PARAMETER Mode
    Chat | Channel | UserChats

.PARAMETER ChatId
    ID chat privata (es. "19:abc...@thread.v2"). Richiesto per Mode=Chat.

.PARAMETER TeamId
    GUID del Team. Richiesto per Mode=Channel.

.PARAMETER ChannelId
    ID del canale (es. "19:abc...@thread.tacv2"). Richiesto per Mode=Channel.

.PARAMETER UserId
    UPN o Object ID. In Mode=UserChats: indica di chi recuperare le chat.
    Non usare come filtro mittente: per quello usare -Users.

.PARAMETER Users
    Lista mittenti separati da virgola (OR tra loro).
    Es: "mario@intrawelt.com,luigi@intrawelt.com"
    Compatibile con tutti i Mode.

.PARAMETER StartDate
    Data inizio filtro inclusiva (es. "2025-01-01").

.PARAMETER EndDate
    Data fine filtro inclusiva (es. "2025-12-31").

.PARAMETER Keywords
    Keyword separate da virgola.
    Es: "fattura,contratto,pagamento"
    Logica OR di default: almeno una deve essere presente nel messaggio.
    Con -KeywordAnd: tutte devono essere presenti (AND).

.PARAMETER KeywordAnd
    Switch. Se presente, le keyword diventano AND invece di OR.

.PARAMETER MatchMode
    Tipo di match per le keyword:
      Insensitive  Substring case-insensitive (default)
      Exact        Substring case-sensitive
      Regex        Espressione regolare (es. "\d{16}" per numeri di carta)
      Word         Parola intera case-insensitive ("rate" non matcha "grateful")

.PARAMETER NoBots
    Switch. Esclude i messaggi inviati da bot o applicazioni.

.PARAMETER OnlyWithAttachments
    Switch. Include solo messaggi che contengono almeno un allegato.

.PARAMETER MentionedUser
    UPN o Object ID. Include solo messaggi in cui quell'utente viene menzionato con @.

.PARAMETER OnlyEdited
    Switch. Include solo messaggi modificati dopo l'invio originale.

.PARAMETER Importance
    Normal | High | Urgent. Filtra per livello di importanza del messaggio.

.PARAMETER OutputFormat
    CSV (default) | JSON

.PARAMETER OutputPath
    Cartella di output. Default: <cartella script>\output\

.PARAMETER Resume
    Switch. Riprende dall'ultimo checkpoint invece di ricominciare da capo.
    Alla prima run completa salva un delta token: le run successive con -Resume
    recuperano solo i messaggi nuovi o modificati (export incrementale).

.EXAMPLE
    # Chat privata: messaggi di due utenti con keyword, in un periodo
    .\Export-TeamsMessages.ps1 -Mode Chat -ChatId "19:xxx@thread.v2" `
        -Users "mario@intrawelt.com,luigi@intrawelt.com" `
        -Keywords "contratto,NDA" -StartDate "2025-01-01" -EndDate "2025-06-30"

.EXAMPLE
    # Canale: messaggi che contengono TUTTE le keyword (AND)
    .\Export-TeamsMessages.ps1 -Mode Channel -TeamId "aaa-bbb" -ChannelId "19:yyy@thread.tacv2" `
        -Keywords "fattura,approvata" -KeywordAnd -MatchMode Insensitive

.EXAMPLE
    # Tutte le chat di un utente, regex per codici fiscali italiani
    .\Export-TeamsMessages.ps1 -Mode UserChats -UserId "mario@intrawelt.com" `
        -Keywords "[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]" -MatchMode Regex

.EXAMPLE
    # Solo filtro data, export JSON
    .\Export-TeamsMessages.ps1 -Mode Channel -TeamId "aaa" -ChannelId "19:yyy" `
        -StartDate "2025-06-01" -OutputFormat JSON
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Chat","Channel","UserChats")]
    [string]$Mode,

    # Sorgente
    [string]$ChatId,
    [string]$TeamId,
    [string]$ChannelId,
    [string]$UserId,

    # Filtri
    [string]$Users,
    [Nullable[datetime]]$StartDate,
    [Nullable[datetime]]$EndDate,
    [string]$Keywords,
    [switch]$KeywordAnd,
    [ValidateSet("Insensitive","Exact","Regex","Word")]
    [string]$MatchMode = "Insensitive",
    [switch]$NoBots,
    [switch]$OnlyWithAttachments,
    [string]$MentionedUser,
    [switch]$OnlyEdited,
    [ValidateSet("","Normal","High","Urgent")]
    [string]$Importance = "",

    # Output
    [switch]$DownloadMedia,
    [ValidateSet("CSV","JSON")]
    [string]$OutputFormat = "CSV",
    [string]$OutputPath = "",
    [switch]$Resume
)

$ErrorActionPreference = "Stop"

# ── INIT ──────────────────────────────────────────────────────────────────────
$scriptRoot = $PSScriptRoot
$configPath = Join-Path $scriptRoot "config.json"
if ($OutputPath -eq "") { $OutputPath = Join-Path $scriptRoot "output" }

$configLocalPath = Join-Path $scriptRoot "config.local.json"
if (Test-Path $configLocalPath) { $configPath = $configLocalPath }
if (-not (Test-Path $configPath)) {
    Write-Error "config.json non trovato in: $scriptRoot"; exit 1
}
$cfg = Get-Content $configPath -Raw | ConvertFrom-Json
foreach ($f in @("TenantId","ClientId","ClientSecret")) {
    if ($cfg.$f -like "INSERISCI*") {
        Write-Error "Compilare '$f' in config.json prima di eseguire."; exit 1
    }
}
$TenantId     = $cfg.TenantId
$ClientId     = $cfg.ClientId
$ClientSecret = $cfg.ClientSecret

# ── CHECKPOINT ───────────────────────────────────────────────────────────────
$checkpointFile = Join-Path $OutputPath "checkpoint.json"

function Read-CheckpointFile {
    if (Test-Path $checkpointFile) {
        return Get-Content $checkpointFile -Raw | ConvertFrom-Json
    }
    return [PSCustomObject]@{ completed = @(); deltaTokens = @{} }
}

function Get-Checkpoint {
    if ($Resume) { return (Read-CheckpointFile).completed } else { return @() }
}

function Get-DeltaToken {
    param([string]$SourceId)
    if (-not $Resume) { return $null }
    $data = Read-CheckpointFile
    if ($data.deltaTokens.PSObject.Properties[$SourceId]) {
        return $data.deltaTokens.$SourceId
    }
    return $null
}

function Save-Checkpoint {
    param([string]$SourceId, [string]$DeltaToken = "")
    $data      = Read-CheckpointFile
    $completed = @($data.completed) + $SourceId | Select-Object -Unique
    $tokens = @{}
    foreach ($p in $data.deltaTokens.PSObject.Properties) { $tokens[$p.Name] = $p.Value }
    if ($DeltaToken) { $tokens[$SourceId] = $DeltaToken }
    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    @{ completed = $completed; deltaTokens = $tokens } |
        ConvertTo-Json -Depth 3 |
        Set-Content -Path $checkpointFile -Encoding UTF8
}

function Clear-Checkpoint {
    if (Test-Path $checkpointFile) { Remove-Item $checkpointFile -Force }
}

# Parse liste
$userList    = if ($Users)    { @($Users    -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } else { @() }
$keywordList = if ($Keywords) { @($Keywords -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } else { @() }

# ── TOKEN (con auto-refresh) ──────────────────────────────────────────────────
$script:CachedToken  = $null
$script:TokenExpires = [datetime]::MinValue

function Get-GraphToken {
    if ($script:CachedToken -and [datetime]::UtcNow -lt $script:TokenExpires) {
        return $script:CachedToken
    }
    $body = @{
        grant_type    = "client_credentials"
        scope         = "https://graph.microsoft.com/.default"
        client_id     = $ClientId
        client_secret = $ClientSecret
    }
    $r = Invoke-RestMethod `
        -Uri    "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -Method POST -Body $body
    $script:CachedToken  = $r.access_token
    $script:TokenExpires = [datetime]::UtcNow.AddSeconds($r.expires_in - 60)
    return $script:CachedToken
}

# ── GRAPH HTTP CON PAGINAZIONE E RETRY ───────────────────────────────────────
function Invoke-GraphRequest {
    param([string]$Uri)
    $maxRetries = 5
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            $headers = @{ Authorization = "Bearer $(Get-GraphToken)" }
            return Invoke-RestMethod -Uri $Uri -Headers $headers -Method GET
        } catch {
            $status = 0
            try { $status = $_.Exception.Response.StatusCode.value__ } catch {}
            if ($status -in @(429, 503) -and $attempt -lt $maxRetries) {
                $retryAfter = 0
                try { $retryAfter = [int]($_.Exception.Response.Headers["Retry-After"]) } catch {}
                # backoff esponenziale con minimo crescente: 10s, 20s, 40s, 80s
                $wait = [math]::Max($retryAfter, [int][math]::Pow(2, $attempt) * 5)
                Write-Warning "  Throttling ($status). Attendo ${wait}s (tentativo $attempt/$maxRetries)..."
                Start-Sleep -Seconds $wait
            } else {
                throw
            }
        }
    }
}

function Invoke-GraphPaged {
    param([string]$Uri)
    $all        = [System.Collections.Generic.List[object]]::new()
    $nextLink   = $Uri
    $deltaToken = $null
    do {
        $r = Invoke-GraphRequest -Uri $nextLink
        if ($r.value)                  { foreach ($i in $r.value) { $all.Add($i) } }
        if ($r.'@odata.deltaLink')     { $deltaToken = $r.'@odata.deltaLink' }
        $nextLink = $r.'@odata.nextLink'  # $null se ultima pagina — il do/while si ferma
    } while ($nextLink)
    return [PSCustomObject]@{ Items = $all; DeltaLink = $deltaToken }
}

# ── UTILITY ───────────────────────────────────────────────────────────────────
function Remove-HtmlTags {
    param([string]$Html)
    if ([string]::IsNullOrEmpty($Html)) { return "" }
    $t = $Html -replace '<br\s*/?>', "`n"
    $t = $t -replace '<[^>]+>', ''
    return [System.Net.WebUtility]::HtmlDecode($t).Trim()
}

# ── MOTORE DI MATCHING ────────────────────────────────────────────────────────
function Test-Keyword {
    param([string]$Text, [string]$Kw)
    switch ($MatchMode) {
        "Exact"       { return $Text.Contains($Kw) }
        "Insensitive" { return $Text.IndexOf($Kw, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }
        "Regex"       { return $Text -match $Kw }
        "Word"        { return $Text -match "(?i)\b$([regex]::Escape($Kw))\b" }
    }
    return $false
}

function Test-MessageMatch {
    param($msg)

    if ($msg.messageType -ne "message") { return $false }

    # Escludi bot/applicazioni
    if ($NoBots -and $msg.from.application) { return $false }

    # Solo messaggi con allegati (@() forza array anche su singolo oggetto JSON)
    if ($OnlyWithAttachments -and @($msg.attachments).Count -eq 0) { return $false }

    # Solo messaggi modificati dopo l'invio
    if ($OnlyEdited -and $msg.lastModifiedDateTime -eq $msg.createdDateTime) { return $false }

    # Filtro importanza
    if ($Importance -ne "" -and $msg.importance -ne $Importance.ToLower()) { return $false }

    # Filtro @mention
    if ($MentionedUser) {
        $hit = $false
        if ($msg.mentions) {
            foreach ($m in $msg.mentions) {
                if ($m.mentioned.user.userPrincipalName -eq $MentionedUser -or
                    $m.mentioned.user.id               -eq $MentionedUser) {
                    $hit = $true; break
                }
            }
        }
        if (-not $hit) { return $false }
    }

    # Filtro data
    $d = [datetime]$msg.createdDateTime
    if ($StartDate -and $d -lt $StartDate) { return $false }
    if ($EndDate) {
        # se EndDate ha solo la data (ora = 00:00:00), estende a fine giornata
        $endBound = if ($EndDate.TimeOfDay.TotalSeconds -eq 0) {
            $EndDate.Date.AddDays(1).AddSeconds(-1)
        } else { $EndDate }
        if ($d -gt $endBound) { return $false }
    }

    # Filtro mittenti (OR): accetta UPN, Object ID o displayName
    if ($userList.Count -gt 0) {
        $uId  = if ($msg.from.user) { $msg.from.user.id          } else { "" }
        $uUpn = if ($msg.from.user) { $msg.from.user.userPrincipalName } else { "" }
        $uDn  = if ($msg.from.user) { $msg.from.user.displayName } else { "" }
        if (-not ($userList | Where-Object { $_ -eq $uId -or $_ -eq $uUpn -or $_ -eq $uDn })) { return $false }
    }

    # Filtro keyword
    if ($keywordList.Count -gt 0) {
        $testo = Remove-HtmlTags $msg.body.content
        if ($KeywordAnd) {
            # AND: tutte le keyword devono essere presenti
            foreach ($kw in $keywordList) {
                if (-not (Test-Keyword -Text $testo -Kw $kw)) { return $false }
            }
        } else {
            # OR: almeno una keyword deve essere presente
            $hit = $false
            foreach ($kw in $keywordList) {
                if (Test-Keyword -Text $testo -Kw $kw) { $hit = $true; break }
            }
            if (-not $hit) { return $false }
        }
    }

    return $true
}

# ── DOWNLOAD MEDIA INLINE (hostedContents) ───────────────────────────────────
function Get-MediaLinks {
    param([string]$Html, [string]$MessageId)
    if (-not $DownloadMedia -or [string]::IsNullOrEmpty($Html)) { return "" }

    $mediaDir = Join-Path $OutputPath "media"
    if (-not (Test-Path $mediaDir)) { New-Item -ItemType Directory -Path $mediaDir -Force | Out-Null }

    $found = [regex]::Matches($Html, 'src="(https://[^"]+/hostedContents/[^"]+/\$value)"')
    if ($found.Count -eq 0) { return "" }

    $saved = [System.Collections.Generic.List[string]]::new()
    $i = 0
    foreach ($m in $found) {
        $url = $m.Groups[1].Value
        try {
            $headers = @{ Authorization = "Bearer $(Get-GraphToken)" }
            $resp    = Invoke-WebRequest -Uri $url -Headers $headers -Method GET -UseBasicParsing
            $ct      = if ($resp.Headers["Content-Type"] -is [array]) { $resp.Headers["Content-Type"][0] } else { $resp.Headers["Content-Type"] }
            $ext     = switch -Wildcard ($ct) {
                "image/jpeg*" { "jpg" }
                "image/png*"  { "png" }
                "image/gif*"  { "gif" }
                "image/webp*" { "webp" }
                default       { "bin" }
            }
            $filename = "${MessageId}_${i}.${ext}"
            [System.IO.File]::WriteAllBytes((Join-Path $mediaDir $filename), $resp.Content)
            $saved.Add($filename)
            $i++
        } catch {
            Write-Warning "  Media non scaricato ($url): $_"
        }
    }
    return $saved -join "; "
}

# ── KEYWORD HIGHLIGHT ─────────────────────────────────────────────────────────
function Add-Highlights {
    param([string]$Text)
    if ($keywordList.Count -eq 0) { return $Text }
    $result = $Text
    foreach ($kw in $keywordList) {
        $pattern = switch ($MatchMode) {
            "Exact"       { [regex]::Escape($kw) }
            "Insensitive" { "(?i)$([regex]::Escape($kw))" }
            "Regex"       { $kw }
            "Word"        { "(?i)\b$([regex]::Escape($kw))\b" }
        }
        $result = [regex]::Replace($result, $pattern, { param($m) "[[$($m.Value)]]" })
    }
    return $result
}

# ── SERIALIZZAZIONE RECORD ────────────────────────────────────────────────────
function ConvertTo-Record {
    param($msg, [string]$Source, [bool]$IsReply, [string]$ParentId)
    $mittente = if ($msg.from.user) { $msg.from.user.displayName } else { "(sistema)" }
    $userId   = if ($msg.from.user) { $msg.from.user.id } else { "" }
    $allegati    = if ($msg.attachments) {
        ($msg.attachments | Where-Object { $_.name }       | ForEach-Object { $_.name })       -join "; "
    } else { "" }
    $attUrls     = if ($msg.attachments) {
        ($msg.attachments | Where-Object { $_.contentUrl } | ForEach-Object { $_.contentUrl }) -join "; "
    } else { "" }
    $mediaFiles  = Get-MediaLinks -Html $msg.body.content -MessageId $msg.id
    [PSCustomObject]@{
        Data           = $msg.createdDateTime
        Mittente       = $mittente
        UserId         = $userId
        Testo          = Add-Highlights (Remove-HtmlTags $msg.body.content)
        IsRisposta     = $IsReply
        ParentId       = $ParentId
        MessageId      = $msg.id
        Source         = $Source
        Allegati       = $allegati
        AttachmentUrls = $attUrls
        MediaFiles     = $mediaFiles
    }
}

# ── FETCH MESSAGGI + RISPOSTE ─────────────────────────────────────────────────
function Get-MessagesWithReplies {
    param([string]$MsgUri, [string]$ReplUriTpl, [string]$Source)

    $completed = Get-Checkpoint
    if ($completed -contains $Source) {
        Write-Host "    [SKIP] $Source gia' completato nel checkpoint" -ForegroundColor DarkYellow
        return @()
    }

    $out      = [System.Collections.Generic.List[object]]::new()
    # Usa delta token se disponibile (incrementale), altrimenti URI base
    $startUri = if ($dt = Get-DeltaToken -SourceId $Source) { $dt } else { "$MsgUri&`$deltaToken=latest" -replace '\?.*&', '?' }
    # Per la prima run usiamo l'URI normale; deltaToken=latest non è supportato su tutti gli endpoint
    $startUri = if (Get-DeltaToken -SourceId $Source) { Get-DeltaToken -SourceId $Source } else { $MsgUri }

    $paged = Invoke-GraphPaged -Uri $startUri
    $msgs  = $paged.Items
    Write-Host "    $($msgs.Count) messaggi$(if ($Resume -and (Get-DeltaToken -SourceId $Source)) {' nuovi (delta)'} else {''}) trovati" -ForegroundColor DarkGray

    foreach ($msg in $msgs) {
        if (Test-MessageMatch -msg $msg) {
            $out.Add((ConvertTo-Record -msg $msg -Source $Source -IsReply $false -ParentId ""))
        }
        $rUri    = $ReplUriTpl -replace '\{id\}', $msg.id
        $replies = @()
        try {
            $replies = (Invoke-GraphPaged -Uri $rUri).Items
        } catch {
            $sc = 0; try { $sc = $_.Exception.Response.StatusCode.value__ } catch {}
            if ($sc -ne 404) { throw }
            # 404 = replies non supportate per questo tipo di messaggio (es. chat 1:1)
        }
        foreach ($reply in $replies) {
            if (Test-MessageMatch -msg $reply) {
                $out.Add((ConvertTo-Record -msg $reply -Source $Source -IsReply $true -ParentId $msg.id))
            }
        }
    }

    Save-Checkpoint -SourceId $Source -DeltaToken $paged.DeltaLink
    return $out
}

# ── MODALITÀ: CHAT PRIVATA ────────────────────────────────────────────────────
function Export-Chat {
    if (-not $ChatId) { Write-Error "Specificare -ChatId per Mode=Chat."; exit 1 }
    Write-Host "  Sorgente: Chat $ChatId" -ForegroundColor Cyan
    $mUri = "https://graph.microsoft.com/v1.0/chats/$ChatId/messages?`$top=50"
    $rTpl = "https://graph.microsoft.com/v1.0/chats/$ChatId/messages/{id}/replies?`$top=50"
    return Get-MessagesWithReplies -MsgUri $mUri -ReplUriTpl $rTpl -Source $ChatId
}

# ── MODALITÀ: CANALE TEAMS ────────────────────────────────────────────────────
function Export-Channel {
    if (-not $TeamId -or -not $ChannelId) { Write-Error "Specificare -TeamId e -ChannelId per Mode=Channel."; exit 1 }
    Write-Host "  Sorgente: Canale $ChannelId (Team: $TeamId)" -ForegroundColor Cyan
    $mUri = "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$ChannelId/messages?`$top=50"
    $rTpl = "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$ChannelId/messages/{id}/replies?`$top=50"
    return Get-MessagesWithReplies -MsgUri $mUri -ReplUriTpl $rTpl -Source "$TeamId/$ChannelId"
}

# ── MODALITÀ: TUTTE LE CHAT DI UN UTENTE ─────────────────────────────────────
function Export-UserChats {
    if (-not $UserId) { Write-Error "Specificare -UserId per Mode=UserChats."; exit 1 }
    Write-Host "  Sorgente: Chat di $UserId" -ForegroundColor Cyan
    $chats = (Invoke-GraphPaged -Uri "https://graph.microsoft.com/v1.0/users/$UserId/chats?`$top=50").Items
    Write-Host "  Chat trovate: $($chats.Count)" -ForegroundColor DarkGray
    $all = [System.Collections.Generic.List[object]]::new()
    foreach ($chat in $chats) {
        Write-Host "  > [$($chat.chatType)] $($chat.id)" -ForegroundColor DarkGray
        try {
            $mUri = "https://graph.microsoft.com/v1.0/chats/$($chat.id)/messages?`$top=50"
            $rTpl = "https://graph.microsoft.com/v1.0/chats/$($chat.id)/messages/{id}/replies?`$top=50"
            $recs = Get-MessagesWithReplies -MsgUri $mUri -ReplUriTpl $rTpl -Source $chat.id
            foreach ($r in $recs) { $all.Add($r) }
        } catch {
            Write-Warning "  Impossibile leggere la chat $($chat.id): $_"
        }
    }
    return $all
}

# ── STATISTICHE ───────────────────────────────────────────────────────────────
function Get-Stats {
    param([array]$Records)
    $stats = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Per utente
    $Records | Group-Object Mittente | Sort-Object Count -Descending | ForEach-Object {
        $stats.Add([PSCustomObject]@{
            StatType = "PerUtente"
            Chiave   = $_.Name
            Valore   = $_.Count
        })
    }

    # Per giorno
    $Records | Group-Object { ([datetime]$_.Data).ToString("yyyy-MM-dd") } | Sort-Object Name | ForEach-Object {
        $stats.Add([PSCustomObject]@{
            StatType = "PerGiorno"
            Chiave   = $_.Name
            Valore   = $_.Count
        })
    }

    # Hit per keyword
    if ($keywordList.Count -gt 0) {
        foreach ($kw in $keywordList) {
            $pattern = switch ($MatchMode) {
                "Exact"       { [regex]::Escape($kw) }
                "Insensitive" { "(?i)$([regex]::Escape($kw))" }
                "Regex"       { $kw }
                "Word"        { "(?i)\b$([regex]::Escape($kw))\b" }
            }
            $hits = ($Records | Where-Object { $_.Testo -match $pattern }).Count
            $stats.Add([PSCustomObject]@{
                StatType = "HitKeyword"
                Chiave   = $kw
                Valore   = $hits
            })
        }
    }
    return $stats
}

# ── SALVATAGGIO ───────────────────────────────────────────────────────────────
function Save-Output {
    param([array]$Records)
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    $ts   = Get-Date -Format "yyyyMMdd_HHmmss"
    $base = "teams_$($Mode.ToLower())_${ts}"
    if ($OutputFormat -eq "JSON") {
        $file = Join-Path $OutputPath "$base.json"
        $Records | ConvertTo-Json -Depth 5 | Set-Content -Path $file -Encoding UTF8
    } else {
        $file = Join-Path $OutputPath "$base.csv"
        $Records | Export-Csv -Path $file -NoTypeInformation -Encoding UTF8
    }
    return $file
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
$kwLogic = if ($KeywordAnd) { "AND" } else { "OR" }
$kwDesc  = if ($keywordList.Count) { "[$($keywordList -join " $kwLogic ")] ($MatchMode)" } else { "(nessun filtro)" }
$usrDesc = if ($userList.Count)    { $userList -join ", " }                                else { "(tutti)" }
$dtDesc  = if ($StartDate -or $EndDate) { "$StartDate -> $EndDate" }                      else { "(nessun filtro)" }

Write-Host "`n=== Export Teams Messages ===" -ForegroundColor Yellow
Write-Host "  Mode      : $Mode"
Write-Host "  Utenti    : $usrDesc"
Write-Host "  Date      : $dtDesc"
Write-Host "  Keywords  : $kwDesc"
if ($MentionedUser)       { Write-Host "  Mention   : $MentionedUser" }
if ($Importance -ne "")   { Write-Host "  Importance: $Importance" }
if ($OnlyEdited)          { Write-Host "  OnlyEdited: si'" }
if ($NoBots)              { Write-Host "  NoBots    : si'" }
if ($OnlyWithAttachments) { Write-Host "  Allegati  : solo messaggi con allegati" }
if ($Resume)              { Write-Host "  Resume    : si' (checkpoint attivo)" -ForegroundColor DarkYellow }
Write-Host ""

$raw = switch ($Mode) {
    "Chat"      { Export-Chat }
    "Channel"   { Export-Channel }
    "UserChats" { Export-UserChats }
}
$records = @($raw | Where-Object { $_ })

if ($records.Count -eq 0) {
    Write-Warning "Nessun messaggio trovato con i filtri specificati."
    exit 0
}

$stats = Get-Stats -Records $records
$file  = Save-Output -Records $records

# Stampa statistiche a console
Write-Host "`n[OK] $($records.Count) messaggi esportati -> $file" -ForegroundColor Green
Write-Host "`n--- Statistiche ---" -ForegroundColor Yellow
$stats | Where-Object { $_.StatType -eq "PerUtente"  } | ForEach-Object { Write-Host "  Utente  $($_.Chiave): $($_.Valore) msg" }
$stats | Where-Object { $_.StatType -eq "PerGiorno"  } | ForEach-Object { Write-Host "  Giorno  $($_.Chiave): $($_.Valore) msg" }
$stats | Where-Object { $_.StatType -eq "HitKeyword" } | ForEach-Object { Write-Host "  Keyword [$($_.Chiave)]: $($_.Valore) hit" }

# Salva statistiche su file separato
$statsFile = $file -replace '\.(csv|json)$', '_stats.csv'
$stats | Export-Csv -Path $statsFile -NoTypeInformation -Encoding UTF8
Write-Host "  Stats   -> $statsFile" -ForegroundColor DarkGray
Clear-Checkpoint
