<#
.SYNOPSIS
    Esporta tutte le chat dirette fra due partecipanti, con autorizzazione e timestamp.
.DESCRIPTION
    Legge partecipanti e autorizzazione da un JSON privato. Produce HTML, TXT, CSV
    e JSON originale nel periodo approvato, senza filtrare un solo mittente.
    Il percorso ordinario richiede firma e verifica umana. Un'istruzione separata
    puo' documentare l'ordine esplicito di esecuzione prima della firma, senza
    attestare una firma o una verifica giuridica non acquisite.
.EXAMPLE
    .\Export-TeamsConversation.ps1 -RequestPath .\_notes\export-request.local.json
#>
[CmdletBinding()]
param(
    [string]$RequestPath = (Join-Path $PSScriptRoot '_notes\export-request.local.json'),
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.local.json'),
    [string]$OutputPath = '',
    [string]$ExecutionInstructionPath = '',
    [string]$EvidencePath = ''
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($field in @('Participant1', 'Participant2', 'Authorization')) {
    if ([string]::IsNullOrWhiteSpace($request.$field)) { throw "Campo obbligatorio nella richiesta: $field" }
}
# La richiesta di esecuzione anticipata resta distinta dall'incarico firmato.
$signedHash = $null
$documentHash = $null
$instructionHash = $null
$authorizationSource = 'Documento firmato verificato manualmente prima di esportare'
if ($ExecutionInstructionPath) {
    $instruction = Get-Content -LiteralPath $ExecutionInstructionPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($field in @('Instruction', 'RecordedAtUtc', 'DocumentPath', 'DocumentSha256', 'RequestSha256')) {
        if ([string]::IsNullOrWhiteSpace([string]$instruction.$field)) { throw "Istruzione incompleta: $field." }
    }
    if ($instruction.Status -ne 'ExecuteBeforeSignature') { throw 'Istruzione di esecuzione anticipata non valida.' }
    if ((Get-FileHash -LiteralPath $RequestPath -Algorithm SHA256).Hash -ne $instruction.RequestSha256) { throw "La richiesta non coincide con l'istruzione di esecuzione." }
    $documentHash = (Get-FileHash -LiteralPath $instruction.DocumentPath -Algorithm SHA256).Hash
    if ($documentHash -ne $instruction.DocumentSha256) { throw "Il documento non coincide con l'istruzione di esecuzione." }
    if ([string]::IsNullOrWhiteSpace($request.Purpose)) { throw 'Indicare lo scopo nella richiesta.' }
    $instructionHash = (Get-FileHash -LiteralPath $ExecutionInstructionPath -Algorithm SHA256).Hash
    $authorizationSource = "Istruzione dell'operatore di procedere prima della sottoscrizione; documento non firmato"
    $request.Authorization = $authorizationSource
} else {
# Questo controllo precede lettura delle credenziali e ogni connessione esterna.
if ($request.Status -ne 'Approved') { throw 'Export sospeso: autorizzazione in bozza, da completare e firmare.' }
foreach ($field in @('Purpose', 'LegalBasis', 'Recipients', 'RetentionUntil', 'ApprovalReference', 'AuthorizationDate', 'SignedAuthorizationPath', 'SignedAuthorizationSha256', 'StartDate', 'EndDateExclusive')) {
    if ([string]::IsNullOrWhiteSpace([string]$request.$field) -or [string]$request.$field -match '(?i)(<[^>]+>|DA COMPILARE|BOZZA)') {
        throw "Autorizzazione incompleta: $field."
    }
}
if ($request.PrerequisitesReviewed -isnot [bool] -or -not $request.PrerequisitesReviewed) { throw 'Verificare firma, base giuridica, proporzionalità e presupposti prima di approvare la richiesta.' }
$signedPath = [string]$request.SignedAuthorizationPath
if (-not [IO.Path]::IsPathRooted($signedPath)) { $signedPath = Join-Path (Split-Path -Parent (Resolve-Path -LiteralPath $RequestPath).Path) $signedPath }
if (-not (Test-Path -LiteralPath $signedPath -PathType Leaf)) { throw 'Documento firmato non trovato.' }
$signedHash = (Get-FileHash -LiteralPath $signedPath -Algorithm SHA256).Hash
if ($signedHash -ne $request.SignedAuthorizationSha256) { throw 'Il documento firmato non coincide con il riferimento approvato.' }
if ([datetimeoffset]::Parse($request.RetentionUntil) -le [datetimeoffset]::UtcNow) { throw 'Il termine di conservazione è scaduto.' }
$documentHash = $signedHash
}
foreach ($field in @('StartDate', 'EndDateExclusive')) {
    if ($request.$field -notmatch '(Z|[+-]\d{2}:\d{2})$') { throw "Indicare esplicitamente il fuso in $field." }
}
$start = [datetimeoffset]::Parse($request.StartDate, [Globalization.CultureInfo]::InvariantCulture)
$end = [datetimeoffset]::Parse($request.EndDateExclusive, [Globalization.CultureInfo]::InvariantCulture)
if ($start -ge $end) { throw 'Il periodo autorizzato non è valido.' }
if ($request.Participant1 -eq $request.Participant2) { throw 'Specificare due partecipanti diversi.' }
$zoneId = if ($request.TimeZoneId) { $request.TimeZoneId } else { 'W. Europe Standard Time' }
$zone = [TimeZoneInfo]::FindSystemTimeZoneById($zoneId)
$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($field in @('TenantId', 'ClientId', 'ClientSecret')) {
    if ([string]::IsNullOrWhiteSpace($config.$field) -or $config.$field -match '^(<|INSERISCI)') {
        throw "Compilare $field nel file di configurazione privato."
    }
}
$script:token = $null
$script:expires = [datetime]::MinValue
$script:evidenceSequence = 0
if ($EvidencePath) {
    if (Test-Path -LiteralPath $EvidencePath) { throw 'Usare una cartella di acquisizione nuova.' }
    New-Item -ItemType Directory -Path (Join-Path $EvidencePath 'risposte') -Force | Out-Null
    $EvidencePath = (Resolve-Path -LiteralPath $EvidencePath).Path
}

function Invoke-ConversationGraph {
    param([string]$Uri, [string]$CollectionUri)
    # Non inviare mai il bearer token fuori dall'endpoint Graph previsto.
    if (([uri]$Uri).Host -ne 'graph.microsoft.com' -or ([uri]$Uri).Scheme -ne 'https') {
        throw 'Endpoint Graph non valido.'
    }
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        if (-not $script:token -or [datetime]::UtcNow -ge $script:expires) {
            $body = @{grant_type='client_credentials';scope='https://graph.microsoft.com/.default';client_id=$config.ClientId;client_secret=$config.ClientSecret}
            $auth = Invoke-RestMethod -Method Post -Uri ('https://login.microsoftonline.com/' + $config.TenantId + '/oauth2/v2.0/token') -Body $body
            $script:token = $auth.access_token
            $script:expires = [datetime]::UtcNow.AddSeconds($auth.expires_in - 60)
        }
        try {
            if ($EvidencePath) {
                $began = [datetimeoffset]::UtcNow.ToString('o')
                $http = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $Uri -Headers @{Authorization=('Bearer ' + $script:token)}
                $script:evidenceSequence++
                $responseName = 'risposte/{0:D6}.json' -f $script:evidenceSequence
                [IO.File]::WriteAllText((Join-Path $EvidencePath $responseName), [string]$http.Content, [Text.UTF8Encoding]::new($false))
                $entry = [ordered]@{Sequence=$script:evidenceSequence;Method='GET';Uri=$Uri;CollectionUri=$CollectionUri;StartedAtUtc=$began;ReceivedAtUtc=[datetimeoffset]::UtcNow.ToString('o');StatusCode=[int]$http.StatusCode;RequestId=$http.Headers['request-id'];ServerDate=$http.Headers['Date'];Response=$responseName;Sha256=(Get-FileHash -LiteralPath (Join-Path $EvidencePath $responseName) -Algorithm SHA256).Hash}
                ($entry | ConvertTo-Json -Compress) | Add-Content -LiteralPath (Join-Path $EvidencePath 'richieste.jsonl') -Encoding UTF8
                return ($http.Content | ConvertFrom-Json)
            }
            return Invoke-RestMethod -Method Get -Uri $Uri -Headers @{Authorization=('Bearer ' + $script:token)}
        } catch {
            $status = 0
            try { $status = [int]$_.Exception.Response.StatusCode } catch {}
            if ($status -notin @(429, 503) -or $attempt -eq 5) { throw }
            $retryAfter = 0
            try { $retryAfter = [int]$_.Exception.Response.Headers['Retry-After'] } catch {}
            $delay = [Math]::Max($retryAfter, [int][Math]::Pow(2, $attempt) * 5)
            Write-Warning "Graph $status, nuovo tentativo fra $delay secondi."
            Start-Sleep -Seconds $delay
        }
    }
}

function Get-ConversationCollection {
    param([string]$Uri, [string]$Label, [switch]$MessagesInPeriod)
    $items = [System.Collections.Generic.List[object]]::new()
    $page = 0
    $collectionUri = $Uri
    do {
        $response = Invoke-ConversationGraph -Uri $Uri -CollectionUri $collectionUri
        $pastStart = $false
        foreach ($item in $response.value) {
            if ($MessagesInPeriod) {
                $created = [datetimeoffset]$item.createdDateTime
                if ($created -lt $start) { $pastStart = $true; continue }
                if ($created -ge $end) { continue }
            }
            $items.Add($item)
        }
        $Uri = $response.'@odata.nextLink'
        # L'endpoint messaggi e' richiesto in ordine createdDateTime decrescente.
        if ($MessagesInPeriod -and $pastStart) { $Uri = $null }
        $page++
        if ($page % 10 -eq 0) { Write-Host "${Label}: $($items.Count) elementi recuperati..." }
        if ($Uri) { Start-Sleep -Milliseconds 300 }
    } while ($Uri)
    return ,$items.ToArray()
}

function Resolve-ConversationParticipant {
    param([string]$Name, [object[]]$Directory)
    # Il nome in directory puo' essere scritto cognome-nome o nome-cognome.
    $tokens = @($Name -split '\s+' | Where-Object { $_ })
    $matches = @($Directory | Where-Object {
        $displayTokens = @($_.displayName -split '[\s,;()]+' | Where-Object { $_ })
        $missing = @($tokens | Where-Object { $displayTokens -notcontains $_ })
        $missing.Count -eq 0
    })
    if ($matches.Count -ne 1) { throw "Il nome '$Name' identifica $($matches.Count) utenti: verificare il nome nella richiesta privata." }
    return $matches[0]
}

function Convert-ConversationBody {
    param($Body)
    if ($Body.contentType -ne 'html') { return [string]$Body.content }
    $text = [regex]::Replace([string]$Body.content, '(?is)<img\b[^>]*>', '[immagine inline]')
    $text = [regex]::Replace($text, '(?is)<br\s*/?>|</(?:p|div|li|blockquote|tr)\s*>', "`n")
    $text = [regex]::Replace($text, '(?is)<[^>]*>', '')
    return [Net.WebUtility]::HtmlDecode($text).Trim()
}

function Encode-ConversationHtml {
    param([string]$Value)
    return [Net.WebUtility]::HtmlEncode($Value)
}

Write-Host 'Risoluzione dei due partecipanti...'
$nameTokens = @(($request.Participant1 + ' ' + $request.Participant2) -split '\s+' | Where-Object { $_ } | Select-Object -Unique)
$filter = ($nameTokens | ForEach-Object { "startswith(displayName,'$($_.Replace("'", "''"))')" }) -join ' or '
$directory = Get-ConversationCollection ('https://graph.microsoft.com/v1.0/users?$select=id,displayName&$top=999&$filter=' + [uri]::EscapeDataString($filter)) 'Directory'
$first = Resolve-ConversationParticipant $request.Participant1 $directory
$second = Resolve-ConversationParticipant $request.Participant2 $directory
$participantIds = @($first.id, $second.id)
Write-Host "Partecipanti: $($first.displayName) / $($second.displayName)"
$userPath = [uri]::EscapeDataString($first.id)
$chats = Get-ConversationCollection ('https://graph.microsoft.com/v1.0/users/' + $userPath + '/chats?$top=50&$expand=members') 'Chat'
$direct = @($chats | Where-Object {
    $memberIds = @($_.members | ForEach-Object { $_.userId })
    $_.chatType -eq 'oneOnOne' -and $memberIds.Count -eq 2 -and $memberIds -contains $first.id -and $memberIds -contains $second.id
})
if ($direct.Count -eq 0) { throw 'Nessuna chat diretta fra i due partecipanti trovata. Nessun messaggio di altri gruppi viene esportato.' }
Write-Host "Chat dirette trovate: $($direct.Count)"

$originals = [System.Collections.Generic.List[object]]::new()
$messages = [System.Collections.Generic.List[object]]::new()
$seen = @{}
foreach ($chat in $direct) {
    $chatPath = [uri]::EscapeDataString($chat.id)
    # Verifica con l'endpoint completo dei membri, prima di leggere i messaggi.
    $members = Get-ConversationCollection ('https://graph.microsoft.com/v1.0/chats/' + $chatPath + '/members') 'Membri'
    $ids = @($members | ForEach-Object { $_.userId })
    if ($ids.Count -ne 2 -or $ids -notcontains $first.id -or $ids -notcontains $second.id) {
        throw 'I membri della chat non coincidono con i partecipanti richiesti.'
    }
    $upperFilter = [uri]::EscapeDataString('createdDateTime lt ' + $end.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))
    $raw = Get-ConversationCollection ('https://graph.microsoft.com/v1.0/chats/' + $chatPath + '/messages?$top=50&$orderby=createdDateTime%20desc&$filter=' + $upperFilter) 'Messaggi' -MessagesInPeriod
    $originals.Add([pscustomobject]@{ChatId=$chat.id;Messages=@($raw)})
    foreach ($msg in $raw) {
        if ($msg.messageType -ne 'message') { continue }
        $key = $chat.id + '/' + $msg.id
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $created = [datetimeoffset]$msg.createdDateTime
        $local = [TimeZoneInfo]::ConvertTime($created, $zone)
        $sender = [string]$msg.from.user.displayName
        if (-not $sender) { $sender = '(mittente non disponibile)' }
        $bodyText = Convert-ConversationBody $msg.body
        if ($msg.deletedDateTime) { $bodyText = '[messaggio eliminato; testo non disponibile]' }
        if (-not $bodyText) { $bodyText = '[messaggio senza testo]' }
        $messages.Add([pscustomobject][ordered]@{
            Data=$created.ToUniversalTime().ToString('o')
            TimestampLocale=$local.ToString('yyyy-MM-dd HH:mm:ss.fff zzz')
            Mittente=$sender
            UserId=[string]$msg.from.user.id
            Testo=$bodyText
            MessageId=$msg.id
            ChatId=$chat.id
            ParentId=$msg.replyToId
            ModificatoUtc=$msg.lastEditedDateTime
            EliminatoUtc=$msg.deletedDateTime
            Allegati=(@($msg.attachments | ForEach-Object { $_.name }) -join '; ')
            AttachmentUrls=(@($msg.attachments | ForEach-Object { $_.contentUrl }) -join '; ')
        })
    }
}
$ordered = @($messages | Sort-Object @{Expression={[datetimeoffset]$_.Data}}, ChatId, MessageId)
if ($ordered.Count -eq 0) { throw 'Le chat individuate non contengono messaggi esportabili.' }
if (-not $OutputPath) { $OutputPath = Join-Path $PSScriptRoot ('output\conversation_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
if (Test-Path -LiteralPath $OutputPath) { throw 'Usare una cartella di output nuova per non sovrascrivere un export.' }
New-Item -ItemType Directory -Path $OutputPath | Out-Null
$OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path
$title = "Chat Microsoft Teams - $($request.Participant1) / $($request.Participant2)"
$exported = [datetimeoffset]::UtcNow.ToString('o')
$summary = [pscustomobject][ordered]@{
    Title=$title;Authorization=$request.Authorization;AuthorizationSource=$authorizationSource
    ExecutionInstructionSha256=$instructionHash;ReferenceDocumentSha256=$documentHash;PrerequisitesReviewed=$request.PrerequisitesReviewed
    ApprovalReference=$request.ApprovalReference;AuthorizationDate=$request.AuthorizationDate;SignedAuthorizationSha256=$signedHash
    Purpose=$request.Purpose;LegalBasis=$request.LegalBasis;Recipients=$request.Recipients;RetentionUntil=$request.RetentionUntil
    StartDate=$request.StartDate;EndDateExclusive=$request.EndDateExclusive
    ExportedAtUtc=$exported;TimeZoneId=$zoneId;Scope=('Chat dirette nel periodo richiesto: ' + $request.StartDate + ' <= data < ' + $request.EndDateExclusive + '; entrambi i mittenti, nessun filtro keyword')
    Participants=@([pscustomobject]@{Name=$request.Participant1;DirectoryName=$first.displayName;UserId=$first.id},[pscustomobject]@{Name=$request.Participant2;DirectoryName=$second.displayName;UserId=$second.id})
    ChatIds=@($direct | ForEach-Object { $_.id });MessageCount=$ordered.Count
    FirstTimestampUtc=$ordered[0].Data;LastTimestampUtc=$ordered[-1].Data
    MessageCounts=@($ordered | Group-Object Mittente | Select-Object Name,Count)
    Notes='Le immagini inline sono indicate nel testo; HTML originale, riferimenti a immagini, allegati, reazioni e metadati sono conservati in originale.json. I file allegati non sono scaricati. I messaggi eliminati non sono ricostruibili.'
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputPath 'riepilogo.json') -Encoding UTF8
ConvertTo-Json -InputObject @($originals.ToArray()) -Depth 100 | Set-Content -LiteralPath (Join-Path $OutputPath 'originale.json') -Encoding UTF8
$ordered | Export-Csv -LiteralPath (Join-Path $OutputPath 'messaggi.csv') -NoTypeInformation -Encoding UTF8
$request.Authorization | Set-Content -LiteralPath (Join-Path $OutputPath 'autorizzazione.txt') -Encoding UTF8

$plain = [Text.StringBuilder]::new()
$html = [Text.StringBuilder]::new()
[void]$plain.AppendLine($title).AppendLine().AppendLine($request.Authorization).AppendLine()
[void]$plain.AppendLine("Documento di riferimento SHA256: $documentHash; stato: $authorizationSource")
[void]$plain.AppendLine("Messaggi: $($ordered.Count); chat dirette: $($direct.Count); fuso: $zoneId; export UTC: $exported")
[void]$plain.AppendLine($summary.Scope).AppendLine($summary.Notes).AppendLine()
[void]$html.AppendLine('<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">')
[void]$html.AppendLine('<meta http-equiv="Content-Security-Policy" content="default-src &#39;none&#39;; style-src &#39;unsafe-inline&#39;">')
[void]$html.AppendLine('<title>' + (Encode-ConversationHtml $title) + '</title><style>body{font:15px/1.5 system-ui,sans-serif;background:#f3f5f7;color:#192331;margin:0}main{max-width:960px;margin:auto;padding:28px}header{background:white;padding:24px;border-radius:12px;margin-bottom:28px}h1{font-size:24px;margin:0 0 16px}h2{font-size:17px;border-bottom:1px solid #ccd3dc;padding:10px 0;margin:28px 0 14px}.authorization{border-left:4px solid #284f80;padding-left:14px}.message{max-width:80%;background:white;border:1px solid #dce2e9;border-radius:10px;padding:14px 18px;margin:12px 0;break-inside:avoid}.second{margin-left:auto;background:#e8eff9}.meta{display:flex;justify-content:space-between;gap:16px;font-size:13px;color:#46556b}time{white-space:nowrap}.text{white-space:pre-wrap;overflow-wrap:anywhere;margin:8px 0 0}.detail{font-size:12px;color:#566274;overflow-wrap:anywhere}.note{font-size:13px;color:#566274}@media(max-width:640px){main{padding:14px}.message{max-width:100%}.meta{display:block}}@media print{body{background:white}main{max-width:none;padding:0}header{padding:0}.message{max-width:85%;box-shadow:none}h2{break-after:avoid}}</style></head><body><main><header>')
[void]$html.AppendLine('<h1>' + (Encode-ConversationHtml $title) + '</h1><p class="authorization">' + (Encode-ConversationHtml $request.Authorization) + '</p>')
[void]$html.AppendLine('<p>Messaggi: ' + $ordered.Count + ' | Chat dirette: ' + $direct.Count + ' | Fuso: ' + (Encode-ConversationHtml $zoneId) + '</p>')
[void]$html.AppendLine('<p>Dal ' + (Encode-ConversationHtml $ordered[0].TimestampLocale) + ' al ' + (Encode-ConversationHtml $ordered[-1].TimestampLocale) + '</p>')
[void]$html.AppendLine('<p class="note">' + (Encode-ConversationHtml $summary.Scope) + '</p><p class="note">' + (Encode-ConversationHtml $summary.Notes) + '</p><p class="note">Export UTC: ' + $exported + '. Riferimento: ' + (Encode-ConversationHtml $request.ApprovalReference) + '. Documento SHA256: ' + $documentHash + '. ' + (Encode-ConversationHtml $authorizationSource) + '.</p></header>')
$day = ''
$index = 0
foreach ($msg in $ordered) {
    $index++
    $date = $msg.TimestampLocale.Substring(0,10)
    if ($date -ne $day) { $day = $date; [void]$html.AppendLine('<h2>' + $day + '</h2>') }
    $class = if ($msg.UserId -eq $second.id) { 'message second' } else { 'message' }
    [void]$plain.AppendLine("[$($msg.TimestampLocale)] $($msg.Mittente) (messaggio $index)").AppendLine($msg.Testo)
    [void]$html.AppendLine('<article class="' + $class + '" id="message-' + $index + '"><div class="meta"><strong>' + (Encode-ConversationHtml $msg.Mittente) + '</strong><time>' + (Encode-ConversationHtml $msg.TimestampLocale) + '</time></div><p class="text">' + (Encode-ConversationHtml $msg.Testo) + '</p>')
    $detail = "#$index | ID: $($msg.MessageId)"
    if ($direct.Count -gt 1) { $detail += " | Chat: $($msg.ChatId)" }
    if ($msg.ParentId) { $detail += " | Risposta a: $($msg.ParentId)" }
    if ($msg.ModificatoUtc) { $detail += " | Modificato UTC: $($msg.ModificatoUtc)" }
    if ($msg.EliminatoUtc) { $detail += " | Eliminato UTC: $($msg.EliminatoUtc)" }
    if ($msg.Allegati) { $detail += " | Allegati: $($msg.Allegati)" }
    if ($msg.AttachmentUrls) { $detail += " | URL allegati: $($msg.AttachmentUrls)" }
    [void]$plain.AppendLine($detail).AppendLine()
    [void]$html.AppendLine('<p class="detail">' + (Encode-ConversationHtml $detail) + '</p></article>')
}
[void]$html.AppendLine('</main></body></html>')
$plain.ToString() | Set-Content -LiteralPath (Join-Path $OutputPath 'conversazione.txt') -Encoding UTF8
$html.ToString() | Set-Content -LiteralPath (Join-Path $OutputPath 'conversazione.html') -Encoding UTF8
Get-ChildItem -LiteralPath $OutputPath -File | Where-Object { $_.Name -ne 'sha256.csv' } | Get-FileHash -Algorithm SHA256 | Select-Object @{Name='File';Expression={Split-Path -Leaf $_.Path}},Hash | Export-Csv -LiteralPath (Join-Path $OutputPath 'sha256.csv') -NoTypeInformation -Encoding UTF8
Write-Host "Export completato: $($ordered.Count) messaggi -> $OutputPath"
$summary.MessageCounts | Format-Table -AutoSize | Out-Host
return [pscustomobject]@{OutputPath=$OutputPath;MessageCount=$ordered.Count;HtmlPath=(Join-Path $OutputPath 'conversazione.html')}
