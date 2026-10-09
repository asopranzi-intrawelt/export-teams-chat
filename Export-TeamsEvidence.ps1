<#
.SYNOPSIS
    Acquisisce una conversazione Teams e documenta integrita' e consegna.
.DESCRIPTION
    Produce cinque file: HTML, CSV, archivio tecnico, verbale PDF e SHA256.csv.
    Conserva le risposte Graph della sola conversazione e verifica ogni copia.
    Non appone firme digitali o marche temporali e non certifica la liceita'.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RequestPath,
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.local.json'),
    [string]$ExecutionInstructionPath = '',
    [string]$OutputPath = '',
    [string]$DestinationRoot = '',
    [string]$PythonCommand = 'python'
)
$ErrorActionPreference = 'Stop'
$helper = Join-Path $PSScriptRoot 'tools\teams_evidence.py'
& $PythonCommand $helper dependencies | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Dipendenze mancanti: installare requirements-evidence.txt prima di acquisire dati.' }
if (-not $OutputPath) { $OutputPath = Join-Path $PSScriptRoot ('output\TeamsEvidence_' + [datetime]::UtcNow.ToString('yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,8)) }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $OutputPath) { throw 'La cartella di output esiste gia: scegliere una cartella nuova.' }
$destination = ''
if ($DestinationRoot) {
    if (-not (Test-Path -LiteralPath $DestinationRoot -PathType Container)) { throw 'Cartella di destinazione non raggiungibile.' }
    $destination = Join-Path $DestinationRoot ([IO.Path]::GetFileName($OutputPath))
    if (Test-Path -LiteralPath $destination) { throw 'La cartella di consegna esiste gia: nessun file viene sovrascritto.' }
}
$work = Join-Path $PSScriptRoot ('_notes\acquisizioni\' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$RequestPath = (Resolve-Path -LiteralPath $RequestPath).Path
$request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
Copy-Item -LiteralPath $RequestPath -Destination (Join-Path $work 'richiesta.json')
$documentPath = ''
if ($ExecutionInstructionPath) {
    $ExecutionInstructionPath = (Resolve-Path -LiteralPath $ExecutionInstructionPath).Path
    $instruction = Get-Content -LiteralPath $ExecutionInstructionPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $documentPath = [string]$instruction.DocumentPath
    Copy-Item -LiteralPath $ExecutionInstructionPath -Destination (Join-Path $work 'istruzione.json')
} else {
    $documentPath = [string]$request.SignedAuthorizationPath
    if ($documentPath -and -not [IO.Path]::IsPathRooted($documentPath)) { $documentPath = Join-Path (Split-Path -Parent $RequestPath) $documentPath }
}
if (-not $documentPath -or -not (Test-Path -LiteralPath $documentPath -PathType Leaf)) { throw 'Documento di riferimento non trovato.' }
Copy-Item -LiteralPath $documentPath -Destination (Join-Path $work ('documento' + [IO.Path]::GetExtension($documentPath)))
$exporter = Join-Path $PSScriptRoot 'Export-TeamsConversation.ps1'
$sourceHash = (Get-FileHash -LiteralPath $exporter -Algorithm SHA256).Hash
Copy-Item -LiteralPath $exporter -Destination (Join-Path $work 'Export-TeamsConversation.ps1')
Copy-Item -LiteralPath $MyInvocation.MyCommand.Path -Destination (Join-Path $work 'Export-TeamsEvidence.ps1')
Copy-Item -LiteralPath $helper -Destination (Join-Path $work 'teams_evidence.py')
$started = [datetimeoffset]::UtcNow.ToString('o')
$run = [ordered]@{Status='Started';StartedAtUtc=$started;Operator=[Environment]::UserName;Machine=[Environment]::MachineName;PowerShellVersion=$PSVersionTable.PSVersion.ToString();ExporterSha256=$sourceHash;EvidenceToolSha256=(Get-FileHash -LiteralPath (Join-Path $work 'Export-TeamsEvidence.ps1') -Algorithm SHA256).Hash;EvidenceHelperSha256=(Get-FileHash -LiteralPath (Join-Path $work 'teams_evidence.py') -Algorithm SHA256).Hash;Destination=$destination;ReferenceDocumentExtension=[IO.Path]::GetExtension($documentPath)}
$runPath = Join-Path $work 'esito.json'
$run | ConvertTo-Json | Set-Content -LiteralPath $runPath -Encoding UTF8
try {
    $parameters = @{RequestPath=$RequestPath;ConfigPath=$ConfigPath;OutputPath=(Join-Path $work 'export');EvidencePath=(Join-Path $work 'http')}
    if ($ExecutionInstructionPath) { $parameters.ExecutionInstructionPath = $ExecutionInstructionPath }
    $result = & $exporter @parameters
    if ((Get-FileHash -LiteralPath $exporter -Algorithm SHA256).Hash -ne $sourceHash) { throw 'Il codice e cambiato durante l acquisizione.' }
    if ((Get-FileHash -LiteralPath $RequestPath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $work 'richiesta.json') -Algorithm SHA256).Hash) { throw 'La richiesta e cambiata durante l acquisizione.' }
    if ((Get-FileHash -LiteralPath $documentPath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $work ('documento' + [IO.Path]::GetExtension($documentPath))) -Algorithm SHA256).Hash) { throw 'Il documento e cambiato durante l acquisizione.' }
    $run.Status = 'Acquired'
    $run.EndedAtUtc = [datetimeoffset]::UtcNow.ToString('o')
    $run.MessageCount = $result.MessageCount
    $run | ConvertTo-Json | Set-Content -LiteralPath $runPath -Encoding UTF8
    & $PythonCommand $helper package --work $work --output $OutputPath | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Verifica o preparazione del pacchetto non riuscita.' }
    if ($destination) {
        New-Item -ItemType Directory -Path $destination | Out-Null
        $verified = @()
        foreach ($file in @('Conversazione.html','Conversazione.csv','Acquisizione_tecnica.zip')) {
            $local = Join-Path $OutputPath $file
            $remote = Join-Path $destination $file
            Copy-Item -LiteralPath $local -Destination $remote
            $localHash = (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash
            $remoteHash = (Get-FileHash -LiteralPath $remote -Algorithm SHA256).Hash
            if ($localHash -ne $remoteHash) { throw "Copia non conforme: $file" }
            $verified += [pscustomobject]@{File=$file;Bytes=(Get-Item -LiteralPath $remote).Length;SHA256=$remoteHash}
        }
        [ordered]@{Status='Verified';VerifiedAtUtc=[datetimeoffset]::UtcNow.ToString('o');Destination=$destination;Files=$verified} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $work 'consegna-dati.json') -Encoding UTF8
        & $PythonCommand $helper report --work $work --output $OutputPath | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Aggiornamento del verbale di consegna non riuscito.' }
        foreach ($file in @('Verbale_acquisizione.pdf','SHA256.csv')) { Copy-Item -LiteralPath (Join-Path $OutputPath $file) -Destination (Join-Path $destination $file) }
        $verified = @()
        foreach ($local in (Get-ChildItem -LiteralPath $OutputPath -File)) {
            $remote = Join-Path $destination $local.Name
            $localHash = (Get-FileHash -LiteralPath $local.FullName -Algorithm SHA256).Hash
            $remoteHash = (Get-FileHash -LiteralPath $remote -Algorithm SHA256).Hash
            if ($localHash -ne $remoteHash) { throw "Copia non conforme: $($local.Name)" }
            $verified += [pscustomobject]@{File=$local.Name;Bytes=(Get-Item -LiteralPath $remote).Length;SHA256=$remoteHash}
        }
        [ordered]@{Status='Verified';VerifiedAtUtc=[datetimeoffset]::UtcNow.ToString('o');Destination=$destination;Files=$verified} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $work 'consegna-finale.json') -Encoding UTF8
    }
    & $PythonCommand $helper verify --output $OutputPath --work $work | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Verifica finale non riuscita.' }
    $run.Status = if ($destination) { 'DeliveredAndVerified' } else { 'PackagedAndVerified' }
    $run | ConvertTo-Json | Set-Content -LiteralPath $runPath -Encoding UTF8
    Write-Host "Pacchetto verificato: $OutputPath"
    if ($destination) { Write-Host "Consegna verificata: $destination" }
    $manifestHash = (Get-FileHash -LiteralPath (Join-Path $OutputPath 'SHA256.csv') -Algorithm SHA256).Hash
    Write-Host "Manifesto SHA-256: $manifestHash"
    return [pscustomobject]@{OutputPath=$OutputPath;Destination=$destination;WorkPath=$work;MessageCount=$result.MessageCount;ReportPath=(Join-Path $OutputPath 'Verbale_acquisizione.pdf');ManifestSha256=$manifestHash}
} catch {
    $run.Status = 'Failed'
    $run.Error = $_.Exception.Message
    $run.FailedAtUtc = [datetimeoffset]::UtcNow.ToString('o')
    $run | ConvertTo-Json | Set-Content -LiteralPath $runPath -Encoding UTF8
    throw
}
