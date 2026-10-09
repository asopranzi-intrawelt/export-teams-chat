<# Prova completa con sole fixture sintetiche e HTTP simulato. #>
[CmdletBinding()]
param([string]$EvidenceToolPath = '', [string]$HelperPath = '')
$ErrorActionPreference = 'Stop'
# Riutilizza le fixture HTTP e le verifiche del recupero, senza dati reali.
. (Join-Path $PSScriptRoot 'Test-TeamsConversation.ps1')
$root = Split-Path -Parent $PSScriptRoot
$tool = if ($EvidenceToolPath) { $EvidenceToolPath } else { Join-Path $root 'Export-TeamsEvidence.ps1' }
$helper = if ($HelperPath) { $HelperPath } else { Join-Path $root 'tools\teams_evidence.py' }
$local = Join-Path $testDir 'pacchetto'
$destinationRoot = Join-Path $testDir 'destinazione'
New-Item -ItemType Directory -Path $destinationRoot | Out-Null
$result = & $tool -RequestPath $requestPath -ConfigPath $configPath -ExecutionInstructionPath $instructionPath -OutputPath $local -DestinationRoot $destinationRoot
Assert-Test ($result.MessageCount -eq 4) 'Tool completo: quattro messaggi'
Assert-Test ((Get-ChildItem -LiteralPath $local -File).Count -eq 5) 'Consegna raccolta in cinque file'
Assert-Test ((Get-ChildItem -LiteralPath $result.Destination -File).Count -eq 5) 'Cinque file arrivano alla destinazione'
$receipt = Get-Content -LiteralPath (Join-Path $result.WorkPath 'consegna-finale.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Test ($receipt.Status -eq 'Verified' -and $receipt.Files.Count -eq 5) 'Consegna documentata'
foreach ($file in $receipt.Files) {
    Assert-Test ((Get-FileHash -LiteralPath (Join-Path $local $file.File) -Algorithm SHA256).Hash -eq $file.SHA256) 'Ricevuta uguale ai file locali'
    Assert-Test ((Get-FileHash -LiteralPath (Join-Path $result.Destination $file.File) -Algorithm SHA256).Hash -eq $file.SHA256) 'Ricevuta uguale ai file consegnati'
}
$run = Get-Content -LiteralPath (Join-Path $result.WorkPath 'esito.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Test ($run.Status -eq 'DeliveredAndVerified') 'Stato conclusivo effettivo'
# Un output esistente deve essere rifiutato prima di HTTP.
$before = $global:teamsConversationTestRequests.Count
$caught = $false
try { & $tool -RequestPath $requestPath -ConfigPath $configPath -ExecutionInstructionPath $instructionPath -OutputPath $local | Out-Null }
catch { $caught = $true; Assert-Test ($_.Exception.Message -like 'La cartella di output esiste*') 'Errore sul divieto di sovrascrittura' }
Assert-Test ($caught -and $global:teamsConversationTestRequests.Count -eq $before) 'Nessun recupero con output esistente'
# Il controllo deve osservare una modifica reale del file.
$csvPath = Join-Path $local 'Conversazione.csv'
$originalBytes = [IO.File]::ReadAllBytes($csvPath)
$originalHash = (Get-FileHash -LiteralPath $csvPath -Algorithm SHA256).Hash
try {
    Add-Content -LiteralPath $csvPath -Value 'MANOMISSIONE-SINTETICA' -Encoding UTF8
    $savedErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $diagnostic = & python $helper verify --output $local 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorPreference
    Assert-Test ($code -ne 0) 'Manomissione respinta dal verificatore'
    Assert-Test (($diagnostic -join ' ') -match 'Impronta del pacchetto non conforme') 'Difetto specifico osservato'
} finally {
    $ErrorActionPreference = 'Stop'
    [IO.File]::WriteAllBytes($csvPath, $originalBytes)
}
Assert-Test ((Get-FileHash -LiteralPath $csvPath -Algorithm SHA256).Hash -eq $originalHash) 'Ripristino verificato mediante hash'
& python $helper verify --output $local --work $result.WorkPath
Assert-Test ($LASTEXITCODE -eq 0) 'Pacchetto ripristinato verificabile'
& python $helper verify --output $local --expected-manifest-sha256 $result.ManifestSha256
Assert-Test ($LASTEXITCODE -eq 0) 'Manifesto confrontato con riferimento conservato'
$ErrorActionPreference = 'Continue'
$diagnostic = & python $helper verify --output $local --expected-manifest-sha256 '0000' 2>&1
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Assert-Test ($code -ne 0 -and ($diagnostic -join ' ') -match 'Manifesto diverso') 'Impronta di riferimento non conforme respinta'
# Provare anche il percorso ordinario: non viene dichiarata una firma futura.
$request.Status = 'Approved'
$request.PrerequisitesReviewed = $true
$request.LegalBasis = 'Solo test sintetico'
$request.RetentionUntil = [datetimeoffset]::UtcNow.AddDays(1).ToString('o')
$request.SignedAuthorizationPath = $signedPath
$request.SignedAuthorizationSha256 = (Get-FileHash -LiteralPath $signedPath -Algorithm SHA256).Hash
Save-TestRequest
$approved = & $tool -RequestPath $requestPath -ConfigPath $configPath -OutputPath (Join-Path $testDir 'pacchetto-ordinario')
Assert-Test ($approved.MessageCount -eq 4 -and -not $approved.Destination) 'Percorso ordinario con sola preparazione locale'
Write-Host 'OK: tool completo, PDF, manifesti, archive, consegna, cinque copie, rifiuto sovrascrittura, manomissione e ripristino. Nessun accesso a Teams.'
