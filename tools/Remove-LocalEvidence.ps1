<#
.SYNOPSIS
    Elenca e distrugge il materiale acquisito rimasto sul disco locale.
.DESCRIPTION
    Il materiale deve vivere soltanto nelle cartelle indicate dal richiedente. Questo
    strumento raccoglie cio' che resta sotto output/ e _notes/, lo mostra, e solo con
    -Distruggi lo sovrascrive, rinomina e cancella, registrando nome, byte e impronta
    di ogni file rimosso.

    Senza parametri si limita a elencare: la prima esecuzione non distrugge niente e
    serve a leggere l'elenco prima di decidere.

    I fascicoli da firmare e il documento di partenza da cui si derivano i nuovi
    incarichi non sono dati estratti: -Preserva li copia sulla destinazione e ne
    verifica le impronte, e -Distruggi rifiuta di toccarli se quella copia manca.

    Limite dichiarato: la sovrascrittura rende il contenuto irrecuperabile dai normali
    strumenti di recupero su disco magnetico. Su unita' a stato solido non lo attesta,
    perche' wear leveling e TRIM possono lasciare i blocchi originali fuori dalla
    portata del filesystem ma presenti sul supporto.
.EXAMPLE
    .\tools\Remove-LocalEvidence.ps1
    .\tools\Remove-LocalEvidence.ps1 -Preserva
    .\tools\Remove-LocalEvidence.ps1 -Distruggi
#>
[CmdletBinding()]
param(
    [string]$Radice = '',
    [string]$Destinazione = ('\\192.168.20.177\Alessandro e Sonia'),
    [string[]]$Escludi = @(),
    [switch]$Preserva,
    [switch]$Distruggi
)
$ErrorActionPreference = 'Stop'

# $PSScriptRoot e' vuoto dentro il blocco param quando lo script parte con -File: si risolve qui.
if (-not $Radice) {
    $percorsoScript = $MyInvocation.MyCommand.Path
    if (-not $percorsoScript) { $percorsoScript = $PSCommandPath }
    if (-not $percorsoScript) { throw 'Percorso dello script non determinabile: indicare -Radice.' }
    $Radice = Split-Path -Parent (Split-Path -Parent $percorsoScript)
}

# Non sono materiale acquisito: strumenti, appunti di lavoro e cache del progetto.
$conserva = @(
    '_notes/*.py', '_notes/*.ps1', '_notes/*.md', '_notes/*.txt',
    '_notes/normativa-locale.json', '_notes/__pycache__/*'
) + $Escludi

function Test-Conservato {
    param([string]$Relative)
    foreach ($pattern in $conserva) { if ($Relative -like $pattern) { return $true } }
    return $false
}

function Get-Materiale {
    param([string]$Root)
    $items = @()
    foreach ($folder in @('output', '_notes')) {
        $base = Join-Path $Root $folder
        if (-not (Test-Path -LiteralPath $base)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $base -File -Recurse -Force)) {
            $relative = $file.FullName.Substring($Root.Length).TrimStart([char]92).Replace([char]92, '/')
            if (Test-Conservato $relative) { continue }
            $gruppo = if ($relative -like 'output/autorizzazione/*') { 'Fascicoli' }
                      elseif ($relative -like 'output/*') { 'Consegne e inventari' }
                      elseif ($relative -like '_notes/acquisizioni/*') { 'Acquisizioni grezze' }
                      else { 'Richieste, istruzioni e archivi di lavoro' }
            $items += [pscustomobject]@{Gruppo=$gruppo;Relative=$relative;Path=$file.FullName;Bytes=$file.Length}
        }
    }
    return ,$items
}

function Remove-FileSicuro {
    param([string]$Path)
    $file = Get-Item -LiteralPath $Path -Force
    try { $file.Attributes = [IO.FileAttributes]::Normal } catch {}
    $length = $file.Length
    $rng = [Security.Cryptography.RNGCryptoServiceProvider]::new()
    try {
        $stream = [IO.File]::Open($file.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $buffer = New-Object byte[] 65536
            $written = 0L
            while ($written -lt $length) {
                $rng.GetBytes($buffer)
                $chunk = [int][Math]::Min([int64]$buffer.Length, $length - $written)
                $stream.Write($buffer, 0, $chunk)
                $written += $chunk
            }
            $stream.Flush($true)
        } finally { $stream.Dispose() }
    } finally { $rng.Dispose() }
    $renamed = Join-Path $file.DirectoryName ([guid]::NewGuid().ToString('N'))
    Move-Item -LiteralPath $file.FullName -Destination $renamed -Force
    Remove-Item -LiteralPath $renamed -Force
}

$Radice = (Resolve-Path -LiteralPath $Radice).Path
$stamp = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$materiale = Get-Materiale -Root $Radice
if ($materiale.Count -eq 0) { Write-Host 'Nessun materiale acquisito rimasto sul disco locale.'; return }

Write-Host ''
Write-Host ("Materiale trovato sotto " + $Radice + ": " + $materiale.Count + " file, " + ($materiale | Measure-Object Bytes -Sum).Sum + " byte.")
foreach ($gruppo in @('Consegne e inventari', 'Acquisizioni grezze', 'Fascicoli', 'Richieste, istruzioni e archivi di lavoro')) {
    $righe = @($materiale | Where-Object { $_.Gruppo -eq $gruppo })
    if ($righe.Count -eq 0) { continue }
    Write-Host ''
    Write-Host ("=== " + $gruppo + ": " + $righe.Count + " file, " + ($righe | Measure-Object Bytes -Sum).Sum + " byte")
    foreach ($riga in $righe) { Write-Host ("  " + $riga.Relative + "  (" + $riga.Bytes + " byte)") }
}

$fascicoli = @($materiale | Where-Object { $_.Gruppo -eq 'Fascicoli' })
$copia = Join-Path $Destinazione ('Fascicoli_da_firmare_' + $stamp)

if ($Preserva) {
    if ($fascicoli.Count -eq 0) { throw 'Nessun fascicolo da preservare.' }
    if (-not (Test-Path -LiteralPath $Destinazione -PathType Container)) { throw 'Destinazione non raggiungibile.' }
    if (Test-Path -LiteralPath $copia) { throw 'La cartella di preservazione esiste gia.' }
    New-Item -ItemType Directory -Path $copia | Out-Null
    $verificati = @()
    foreach ($file in $fascicoli) {
        $remoto = Join-Path $copia (Split-Path -Leaf $file.Path)
        Copy-Item -LiteralPath $file.Path -Destination $remoto
        $locale = (Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash
        $arrivato = (Get-FileHash -LiteralPath $remoto -Algorithm SHA256).Hash
        if ($locale -ne $arrivato) { throw ("Copia non conforme: " + $file.Relative) }
        $verificati += [pscustomobject]@{File=(Split-Path -Leaf $file.Path);Bytes=$file.Bytes;SHA256=$arrivato}
    }
    $verificati | Export-Csv -LiteralPath (Join-Path $copia 'SHA256.csv') -NoTypeInformation -Encoding UTF8
    Write-Host ''
    Write-Host ("Fascicoli preservati e verificati: " + $verificati.Count + " file in " + $copia)
    Write-Host 'Da qui in avanti i nuovi incarichi si derivano indicando --base su questa copia.'
    return
}

if (-not $Distruggi) {
    Write-Host ''
    Write-Host 'Solo elenco: niente e stato toccato.'
    Write-Host 'Per preservare i fascicoli sulla destinazione, rilanciare con -Preserva.'
    Write-Host 'Per distruggere, rilanciare con -Distruggi.'
    return
}

if ($fascicoli.Count -gt 0) {
    $preservati = @(Get-ChildItem -LiteralPath $Destinazione -Directory -Filter 'Fascicoli_da_firmare_*' -ErrorAction SilentlyContinue)
    if ($preservati.Count -eq 0) {
        throw 'I fascicoli non risultano preservati sulla destinazione: eseguire prima -Preserva.'
    }
    $ultima = @($preservati | Sort-Object Name)[-1]
    $manifesto = @(Import-Csv -LiteralPath (Join-Path $ultima.FullName 'SHA256.csv'))
    foreach ($file in $fascicoli) {
        $nome = Split-Path -Leaf $file.Path
        $voce = @($manifesto | Where-Object { $_.File -eq $nome })
        if ($voce.Count -ne 1) { throw ("Fascicolo non presente nella copia preservata: " + $nome) }
        if ((Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -ne $voce[0].SHA256) {
            throw ("Il fascicolo locale non coincide con la copia preservata: " + $nome)
        }
    }
    Write-Host ''
    Write-Host ("Copia preservata riscontrata: " + $ultima.FullName)
}

$registro = @()
foreach ($file in $materiale) {
    $registro += [pscustomobject]@{
        File = $file.Relative
        Gruppo = $file.Gruppo
        Bytes = $file.Bytes
        SHA256 = (Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash
    }
    Remove-FileSicuro -Path $file.Path
}
foreach ($folder in @('output', '_notes/acquisizioni')) {
    $base = Join-Path $Radice ($folder.Replace('/', [string][char]92))
    if (-not (Test-Path -LiteralPath $base)) { continue }
    foreach ($dir in @(Get-ChildItem -LiteralPath $base -Directory -Recurse -Force | Sort-Object { $_.FullName.Length } -Descending)) {
        if (@(Get-ChildItem -LiteralPath $dir.FullName -Force).Count -eq 0) { Remove-Item -LiteralPath $dir.FullName -Force }
    }
    if (@(Get-ChildItem -LiteralPath $base -Force).Count -eq 0) { Remove-Item -LiteralPath $base -Force }
}

$cartella = Join-Path $Destinazione 'Registri_cancellazione'
if (-not (Test-Path -LiteralPath $cartella)) { New-Item -ItemType Directory -Path $cartella | Out-Null }
$esito = [ordered]@{
    DistruttoAtUtc = [datetimeoffset]::UtcNow.ToString('o')
    Radice = $Radice
    Operatore = [Environment]::UserName
    Macchina = [Environment]::MachineName
    File = $registro.Count
    Bytes = ($registro | Measure-Object Bytes -Sum).Sum
    Limite = "Sovrascrittura con byte casuali, rinomina e cancellazione. Su unita' a stato solido wear leveling e TRIM possono lasciare i blocchi originali fuori dalla portata del filesystem ma presenti sul supporto: la sovrascrittura non attesta l'irrecuperabilita' fisica del dato."
    Rimossi = $registro
}
$percorso = Join-Path $cartella ('cancellazione-' + $stamp + '.json')
$esito | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $percorso -Encoding UTF8
Write-Host ''
Write-Host ("Distrutti " + $registro.Count + " file, " + $esito.Bytes + " byte.")
Write-Host ("Registro: " + $percorso)
Write-Host "Su unita' a stato solido la sovrascrittura non attesta l'irrecuperabilita' fisica del dato."
