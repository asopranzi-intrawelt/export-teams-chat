<# Prove offline: nessun accesso a Teams e nessuna credenziale reale. #>
[CmdletBinding()]
param([string]$ExporterPath = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$global:teamsConversationTestRequests = [System.Collections.Generic.List[string]]::new()
$testDir = Join-Path $root ('_notes\tests\' + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
$exporter = if ($ExporterPath) { $ExporterPath } else { Join-Path $root 'Export-TeamsConversation.ps1' }
$requestPath = Join-Path $testDir 'request.json'
$configPath = Join-Path $testDir 'config.json'
$signedPath = Join-Path $testDir 'firma-sintetica.txt'
'Documento sintetico: nessuna firma reale.' | Set-Content -LiteralPath $signedPath -Encoding UTF8
@{TenantId='tenant-test';ClientId='client-test';ClientSecret='secret-test'} | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
$request = [ordered]@{
    Status='Approved';Participant1='Persona Alfa';Participant2='Persona Beta';Authorization='Autorizzazione esclusivamente sintetica'
    Purpose='Verifica offline con dati sintetici';LegalBasis='Test offline: nessun dato personale reale';Recipients='Destinatario sintetico'
    RetentionUntil=[datetimeoffset]::UtcNow.AddDays(1).ToString('o');ApprovalReference='TEST-OFFLINE';AuthorizationDate='2026-10-09'
    SignedAuthorizationPath=$signedPath;SignedAuthorizationSha256=(Get-FileHash -LiteralPath $signedPath -Algorithm SHA256).Hash
    PrerequisitesReviewed=$true;StartDate='2025-01-01T00:00:00+01:00';EndDateExclusive='2026-01-01T00:00:00+01:00';TimeZoneId='W. Europe Standard Time'
}

function Assert-Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "TEST FALLITO: $Message" }
}
function Save-TestRequest { $request | ConvertTo-Json | Set-Content -LiteralPath $requestPath -Encoding UTF8 }
function Assert-RejectedBeforeNetwork {
    param([string]$Expected)
    Save-TestRequest
    $before = $global:teamsConversationTestRequests.Count
    $caught = $false
    try { & $exporter -RequestPath $requestPath -ConfigPath (Join-Path $testDir 'config-inesistente.json') | Out-Null }
    catch {
        $caught = $true
        Assert-Test ($_.Exception.Message -like $Expected) "Errore inatteso: $($_.Exception.Message)"
    }
    Assert-Test $caught 'La richiesta incompleta deve essere rifiutata'
    Assert-Test ($global:teamsConversationTestRequests.Count -eq $before) 'Nessuna connessione prima della validazione'
}

function New-TestMessage {
    param([string]$Id,[string]$Created,[string]$Sender,[string]$Text,[string]$Parent='')
    [pscustomobject]@{id=$Id;messageType='message';createdDateTime=$Created;from=@{user=@{id=$Sender;displayName=if($Sender -eq 'u-a'){'Alfa Persona'}else{'Beta Persona'}}};body=@{contentType='html';content=$Text};attachments=@();replyToId=$Parent}
}
function Invoke-RestMethod {
    param([string]$Method,[string]$Uri,$Headers,$Body)
    $global:teamsConversationTestRequests.Add($Uri)
    if ($Uri -like 'https://login.microsoftonline.com/*') { return @{access_token='test-token';expires_in=3600} }
    if ($Uri -match '^https://graph\.microsoft\.com/v1\.0/users\?') {
        return @{value=@(@{id='u-a';displayName='Alfa Persona'},@{id='u-b';displayName='Beta Persona'})}
    }
    if ($Uri -like 'https://graph.microsoft.com/v1.0/users/u-a/chats?*') {
        return @{value=@(@{id='group';chatType='group';members=@(@{userId='u-a'},@{userId='u-b'})});'@odata.nextLink'='https://graph.microsoft.com/v1.0/test/chats?page=2'}
    }
    if ($Uri -eq 'https://graph.microsoft.com/v1.0/test/chats?page=2') {
        return @{value=@(@{id='direct';chatType='oneOnOne';members=@(@{userId='u-a'},@{userId='u-b'})},@{id='other';chatType='oneOnOne';members=@(@{userId='u-a'},@{userId='u-other'})})}
    }
    if ($Uri -eq 'https://graph.microsoft.com/v1.0/chats/direct/members') {
        return @{value=@(@{userId='u-a'},@{userId='u-b'})}
    }
    if ($Uri -like 'https://graph.microsoft.com/v1.0/chats/direct/messages?*') {
        Assert-Test ($Uri -match '\$filter=createdDateTime%20lt%20') 'Limite superiore richiesto a Graph'
        return @{value=@(
            (New-TestMessage 'outside-new' '2025-12-31T23:00:00Z' 'u-a' 'FUORI-PERIODO-NUOVO'),
            (New-TestMessage 'm4' '2025-12-31T22:59:59.999Z' 'u-b' '<p>Ultimo</p>'),
            (New-TestMessage 'm3' '2025-06-12T10:00:00Z' 'u-a' '<p>prima</p><p>seconda &amp; &lt;script&gt;alert(1)&lt;/script&gt;</p>')
        );'@odata.nextLink'='https://graph.microsoft.com/v1.0/test/messages?page=2'}
    }
    if ($Uri -eq 'https://graph.microsoft.com/v1.0/test/messages?page=2') {
        return @{value=@(
            (New-TestMessage 'm3' '2025-06-12T10:00:00Z' 'u-a' '<p>prima</p><p>seconda &amp; &lt;script&gt;alert(1)&lt;/script&gt;</p>'),
            (New-TestMessage 'm2' '2025-03-30T01:30:00Z' 'u-b' '<p>Risposta</p>' 'm1'),
            (New-TestMessage 'm1' '2024-12-31T23:00:00Z' 'u-a' '<p>Inizio</p>'),
            (New-TestMessage 'outside-old' '2024-12-31T22:59:59.999Z' 'u-a' 'FUORI-PERIODO-VECCHIO')
        );'@odata.nextLink'='https://graph.microsoft.com/v1.0/test/messages?page=3'}
    }
    throw "HTTP non previsto dal test: $Method $Uri"
}

$request.Status = 'Draft'
Assert-RejectedBeforeNetwork 'Export sospeso:*'
$request.Status = 'Approved'
$savedPurpose = $request.Purpose
$request.Purpose = ''
Assert-RejectedBeforeNetwork 'Autorizzazione incompleta: Purpose*'
$request.Purpose = $savedPurpose
$request.PrerequisitesReviewed = $false
Assert-RejectedBeforeNetwork 'Verificare firma*'
$request.PrerequisitesReviewed = 'false'
Assert-RejectedBeforeNetwork 'Verificare firma*'
$request.PrerequisitesReviewed = $true
$savedHash = $request.SignedAuthorizationSha256
$request.SignedAuthorizationSha256 = '0000'
Assert-RejectedBeforeNetwork 'Il documento firmato non coincide*'
$request.SignedAuthorizationSha256 = $savedHash
$savedEnd = $request.EndDateExclusive
$request.EndDateExclusive = $request.StartDate
Assert-RejectedBeforeNetwork 'Il periodo autorizzato*'
$request.EndDateExclusive = $savedEnd
$savedStart = $request.StartDate
$request.StartDate = '2025-01-01'
Assert-RejectedBeforeNetwork 'Indicare esplicitamente il fuso*'
$request.StartDate = $savedStart
Save-TestRequest
$result = & $exporter -RequestPath $requestPath -ConfigPath $configPath -OutputPath (Join-Path $testDir 'output')
$csv = @(Import-Csv -LiteralPath (Join-Path $result.OutputPath 'messaggi.csv') -Encoding UTF8)
Assert-Test ($csv.Count -eq 4) 'Entrambi i mittenti, deduplicazione e periodo'
Assert-Test (($csv.MessageId -join ',') -eq 'm1,m2,m3,m4') 'Ordine cronologico crescente'
Assert-Test ((@($csv | Group-Object Mittente).Count) -eq 2) 'Botta e risposta preservato'
Assert-Test ($csv[0].TimestampLocale -eq '2025-01-01 00:00:00.000 +01:00') 'Inclusione del limite iniziale in ora italiana'
Assert-Test ($csv[1].TimestampLocale -eq '2025-03-30 03:30:00.000 +02:00') 'Passaggio all ora legale'
Assert-Test ($csv[2].TimestampLocale -eq '2025-06-12 12:00:00.000 +02:00') 'Ora estiva'
Assert-Test ($csv[3].TimestampLocale -eq '2025-12-31 23:59:59.999 +01:00') 'Ultimo millisecondo del periodo'
Assert-Test ($csv[2].Testo -match "prima\r?\nseconda") 'Paragrafi HTML separati'
Assert-Test ($csv[1].ParentId -eq 'm1') 'Riferimento alla risposta'
$html = Get-Content -LiteralPath $result.HtmlPath -Raw -Encoding UTF8
Assert-Test ($html -notmatch '<script>') 'Il testo dei messaggi non esegue HTML'
Assert-Test ($html -match '&lt;script&gt;') 'Il testo originale resta leggibile'
Assert-Test ($html -match 'TEST-OFFLINE' -and $html -match $savedHash) 'Riferimento al documento e hash nel report'
$original = Get-Content -LiteralPath (Join-Path $result.OutputPath 'originale.json') -Raw -Encoding UTF8
Assert-Test ($original -notmatch 'FUORI-PERIODO') 'Nessun contenuto fuori periodo nella copia tecnica'
Assert-Test (($global:teamsConversationTestRequests -join "`n") -notmatch '/(group|other)/messages') 'Nessuna acquisizione di gruppi o altri interlocutori'
Assert-Test (($global:teamsConversationTestRequests -join "`n") -notmatch 'messages\?page=3') 'Stop delle pagine anteriori al periodo'
foreach ($hash in (Import-Csv -LiteralPath (Join-Path $result.OutputPath 'sha256.csv'))) {
    Assert-Test ((Get-FileHash -LiteralPath (Join-Path $result.OutputPath $hash.File) -Algorithm SHA256).Hash -eq $hash.Hash) 'Impronte degli artefatti'
}
Write-Host 'OK: blocchi prima dell accesso, periodo, chat diretta, cronologia, due mittenti, fuso e ora legale, HTML sicuro, riferimenti e hash. Solo HTTP simulato.'

# Istruzione esplicita prima della firma: nessuna approvazione o firma simulata.
$request.Status = 'Draft'
$request.PrerequisitesReviewed = $false
$request.LegalBasis = ''
$request.RetentionUntil = ''
$request.SignedAuthorizationPath = ''
$request.SignedAuthorizationSha256 = ''
Save-TestRequest
$instructionPath = Join-Path $testDir 'istruzione.json'
$instruction = [ordered]@{Status='ExecuteBeforeSignature';Instruction='Eseguire il test senza firma';RecordedAtUtc=[datetimeoffset]::UtcNow.ToString('o');DocumentPath=$signedPath;DocumentSha256=(Get-FileHash -LiteralPath $signedPath -Algorithm SHA256).Hash;RequestSha256=(Get-FileHash -LiteralPath $requestPath -Algorithm SHA256).Hash}
function Save-TestInstruction { $instruction | ConvertTo-Json | Set-Content -LiteralPath $instructionPath -Encoding UTF8 }
function Assert-InstructionRejected {
    param([string]$Expected)
    Save-TestInstruction
    $before = $global:teamsConversationTestRequests.Count
    $caught = $false
    try { & $exporter -RequestPath $requestPath -ExecutionInstructionPath $instructionPath -ConfigPath (Join-Path $testDir 'inesistente.json') | Out-Null }
    catch { $caught = $true; Assert-Test ($_.Exception.Message -like $Expected) 'Errore del controllo istruzione' }
    Assert-Test $caught 'Istruzione non valida rifiutata'
    Assert-Test ($global:teamsConversationTestRequests.Count -eq $before) 'Istruzione controllata prima della rete'
}
$instruction.Status = 'Draft'
Assert-InstructionRejected 'Istruzione di esecuzione anticipata non valida*'
$instruction.Status = 'ExecuteBeforeSignature'
$requestHash = $instruction.RequestSha256
$instruction.RequestSha256 = '0000'
Assert-InstructionRejected 'La richiesta non coincide*'
$instruction.RequestSha256 = $requestHash
$documentHash = $instruction.DocumentSha256
$instruction.DocumentSha256 = '0000'
Assert-InstructionRejected 'Il documento non coincide*'
$instruction.DocumentSha256 = $documentHash
Save-TestInstruction
function Invoke-WebRequest {
    param([switch]$UseBasicParsing,[string]$Method,[string]$Uri,$Headers)
    $response = Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers
    return @{Content=($response | ConvertTo-Json -Depth 50);StatusCode=200;Headers=@{'request-id'='synthetic-request';Date='Fri, 09 Oct 2026 12:00:00 GMT'}}
}
$evidence = Join-Path $testDir 'http'
$early = & $exporter -RequestPath $requestPath -ExecutionInstructionPath $instructionPath -ConfigPath $configPath -OutputPath (Join-Path $testDir 'output-anticipato') -EvidencePath $evidence
$summary = Get-Content -LiteralPath (Join-Path $early.OutputPath 'riepilogo.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Test ($early.MessageCount -eq 4) 'Export anticipato esercita tutta la conversazione'
Assert-Test (-not $summary.SignedAuthorizationSha256 -and -not $summary.PrerequisitesReviewed) 'Firma e verifica non inventate'
Assert-Test ($summary.AuthorizationSource -match 'documento non firmato') 'Stato effettivo nel riepilogo'
Assert-Test ($summary.ReferenceDocumentSha256 -eq $documentHash) 'Documento non firmato identificato'
$log = @(Get-Content -LiteralPath (Join-Path $evidence 'richieste.jsonl') -Encoding UTF8 | ForEach-Object { $_ | ConvertFrom-Json })
Assert-Test ($log.Count -eq 6) 'Ogni risposta Graph è registrata'
foreach ($entry in $log) {
    Assert-Test ((Get-FileHash -LiteralPath (Join-Path $evidence $entry.Response) -Algorithm SHA256).Hash -eq $entry.Sha256) 'Risposte HTTP conservate e impronte corrette'
    Assert-Test ($entry.StatusCode -eq 200 -and $entry.RequestId -eq 'synthetic-request') 'Metadati HTTP conservati'
}
Assert-Test ((Get-Content -LiteralPath (Join-Path $evidence 'richieste.jsonl') -Raw) -notmatch 'test-token|secret-test|Bearer') 'Registro senza credenziali'
Write-Host 'OK: istruzione esplicita, hash vincolanti, stato non firmato e risposte Graph registrate. Solo HTTP simulato.'

