<#
.SYNOPSIS
    Converte un export CSV di Export-TeamsMessages.ps1 in un documento Word .docx
    con le immagini inline incorporate.

.DESCRIPTION
    Legge il CSV prodotto da Export-TeamsMessages.ps1 e genera un .docx tramite
    automazione COM di Microsoft Word. Per ogni messaggio scrive un'intestazione
    (progressivo, data/ora locale, mittente) seguita dal testo e dalle immagini
    elencate nel campo MediaFiles, cercate nella cartella media.

    Richiede Microsoft Word installato sulla macchina.

.PARAMETER CsvPath
    Percorso del CSV di export. Obbligatorio.

.PARAMETER DocxPath
    Percorso del .docx da creare. Default: stesso nome del CSV con estensione .docx.

.PARAMETER MediaPath
    Cartella con le immagini scaricate da -DownloadMedia.
    Default: sottocartella "media" della cartella del CSV.

.PARAMETER Title
    Titolo in prima pagina. Default: "Export chat Microsoft Teams".

.PARAMETER Subtitle
    Riga descrittiva sotto il titolo (finestra temporale, mittente, ecc.).

.PARAMETER MaxImageWidthPt
    Larghezza massima delle immagini in punti. Default: larghezza utile pagina.

.EXAMPLE
    .\ConvertTo-Docx.ps1 -CsvPath ".\output\teams_chat_20260728_140000.csv" `
        -Title "Messaggi di <IT-manager>" `
        -Subtitle "28/07/2026 dalle 12:49 all'ultimo messaggio"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [string]$DocxPath = "",
    [string]$MediaPath = "",
    [string]$Title = "Export chat Microsoft Teams",
    [string]$Subtitle = "",
    [double]$MaxImageWidthPt = 0
)

$ErrorActionPreference = "Stop"

# ── COSTANTI WORD ─────────────────────────────────────────────────────────────
$wdFormatDocumentDefault = 16    # .docx
$wdAlignParagraphLeft    = 0
$wdAlignParagraphCenter  = 1
$msoTrue                 = -1
# Stili built-in per indice numerico: indipendenti dalla lingua di Word
$wdStyleNormal           = -1
$wdStyleHeading1         = -2
$wdStyleHeading3         = -4

# ── VALIDAZIONE INPUT ─────────────────────────────────────────────────────────
$CsvPath = (Resolve-Path -LiteralPath $CsvPath).Path
if (-not (Test-Path -LiteralPath $CsvPath)) { Write-Error "CSV non trovato: $CsvPath"; exit 1 }

$csvDir = Split-Path -Parent $CsvPath
if ($DocxPath  -eq "") { $DocxPath  = [System.IO.Path]::ChangeExtension($CsvPath, ".docx") }
if ($MediaPath -eq "") { $MediaPath = Join-Path $csvDir "media" }
if (-not [System.IO.Path]::IsPathRooted($DocxPath)) {
    $DocxPath = Join-Path (Get-Location).Path $DocxPath
}

$records = @(Import-Csv -LiteralPath $CsvPath -Encoding UTF8)
if ($records.Count -eq 0) { Write-Error "Il CSV non contiene messaggi: $CsvPath"; exit 1 }

# Ordine cronologico crescente: l'API Graph restituisce dal piu' recente
$records = @($records | Sort-Object { [datetimeoffset]$_.Data })

Write-Host "`n=== Conversione in Word ===" -ForegroundColor Yellow
Write-Host "  CSV      : $CsvPath"
Write-Host "  Messaggi : $($records.Count)"
Write-Host "  Media    : $MediaPath"
Write-Host "  Output   : $DocxPath"
Write-Host ""

# ── AVVIO WORD ────────────────────────────────────────────────────────────────
$word = $null
$doc  = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible       = $false
    $word.DisplayAlerts = 0

    $doc = $word.Documents.Add()
    $sel = $word.Selection

    # Larghezza utile della pagina, per non far sbordare le immagini
    $ps = $doc.PageSetup
    $usableWidth = $ps.PageWidth - $ps.LeftMargin - $ps.RightMargin
    if ($MaxImageWidthPt -le 0) { $MaxImageWidthPt = $usableWidth }
    if ($MaxImageWidthPt -gt $usableWidth) { $MaxImageWidthPt = $usableWidth }

    # ── FRONTESPIZIO ─────────────────────────────────────────────────────────
    $sel.Style = $doc.Styles.Item($wdStyleHeading1)
    $sel.ParagraphFormat.Alignment = $wdAlignParagraphLeft
    $sel.TypeText($Title)
    $sel.TypeParagraph()

    $sel.Style = $doc.Styles.Item($wdStyleNormal)
    if ($Subtitle -ne "") {
        $sel.Font.Italic = $msoTrue
        $sel.TypeText($Subtitle)
        $sel.Font.Italic = 0
        $sel.TypeParagraph()
    }

    $first = ([datetimeoffset]$records[0].Data).ToLocalTime()
    $last  = ([datetimeoffset]$records[-1].Data).ToLocalTime()
    $meta  = @(
        "Messaggi: $($records.Count)"
        "Primo: $($first.ToString('dd/MM/yyyy HH:mm:ss'))"
        "Ultimo: $($last.ToString('dd/MM/yyyy HH:mm:ss'))"
        "Generato: $((Get-Date).ToString('dd/MM/yyyy HH:mm'))"
    ) -join "  |  "
    $sel.Font.Size = 9
    $sel.TypeText($meta)
    $sel.Font.Size = 11
    $sel.TypeParagraph()
    $sel.TypeParagraph()

    # ── MESSAGGI ──────────────────────────────────────────────────────────────
    $imgOk      = 0
    $imgMissing = [System.Collections.Generic.List[string]]::new()
    $n          = 0

    foreach ($r in $records) {
        $n++
        $when = ([datetimeoffset]$r.Data).ToLocalTime().ToString('dd/MM/yyyy HH:mm:ss')

        # Intestazione messaggio
        $sel.Style = $doc.Styles.Item($wdStyleHeading3)
        $sel.TypeText("$n. $when - $($r.Mittente)")
        $sel.TypeParagraph()
        $sel.Style = $doc.Styles.Item($wdStyleNormal)

        # Testo
        $testo = if ($r.Testo) { $r.Testo.Trim() } else { "" }
        if ($testo -ne "") {
            # Word usa CR come separatore di paragrafo
            $sel.TypeText(($testo -replace "`r`n", "`r" -replace "`n", "`r"))
            $sel.TypeParagraph()
        } elseif (-not $r.MediaFiles -and -not $r.Allegati) {
            $sel.Font.Italic = $msoTrue
            $sel.TypeText("(messaggio senza testo)")
            $sel.Font.Italic = 0
            $sel.TypeParagraph()
        }

        # Immagini inline
        if ($r.MediaFiles) {
            foreach ($f in ($r.MediaFiles -split ';')) {
                $name = $f.Trim()
                if ($name -eq "") { continue }
                $full = Join-Path $MediaPath $name
                if (-not (Test-Path -LiteralPath $full)) {
                    $imgMissing.Add($name)
                    $sel.Font.Italic = $msoTrue
                    $sel.TypeText("[immagine non trovata: $name]")
                    $sel.Font.Italic = 0
                    $sel.TypeParagraph()
                    continue
                }
                try {
                    $shape = $sel.InlineShapes.AddPicture($full, $false, $true)
                    $shape.LockAspectRatio = $msoTrue
                    if ($shape.Width -gt $MaxImageWidthPt) { $shape.Width = $MaxImageWidthPt }
                    $sel.TypeParagraph()

                    # Didascalia con il nome file, per tracciabilita'
                    $sel.Font.Size   = 8
                    $sel.Font.Italic = $msoTrue
                    $sel.TypeText($name)
                    $sel.Font.Italic = 0
                    $sel.Font.Size   = 11
                    $sel.TypeParagraph()
                    $imgOk++
                } catch {
                    Write-Warning "  Immagine non inserita ($name): $_"
                    $imgMissing.Add($name)
                }
            }
        }

        # Allegati file (non inline: solo riferimento)
        if ($r.Allegati) {
            $sel.Font.Size = 9
            $sel.TypeText("Allegati: $($r.Allegati)")
            $sel.Font.Size = 11
            $sel.TypeParagraph()
        }
        if ($r.AttachmentUrls) {
            $sel.Font.Size = 8
            $sel.TypeText("URL allegati: $($r.AttachmentUrls)")
            $sel.Font.Size = 11
            $sel.TypeParagraph()
        }
    }

    # ── SALVATAGGIO ───────────────────────────────────────────────────────────
    if (Test-Path -LiteralPath $DocxPath) { Remove-Item -LiteralPath $DocxPath -Force }
    $doc.SaveAs2($DocxPath, $wdFormatDocumentDefault)
    $pages = $doc.ComputeStatistics(2)   # wdStatisticPages
    $doc.Close(0)
    $doc = $null

    Write-Host "  Immagini inserite : $imgOk" -ForegroundColor Green
    if ($imgMissing.Count -gt 0) {
        Write-Host "  Immagini mancanti : $($imgMissing.Count) ($($imgMissing -join ', '))" -ForegroundColor DarkYellow
    }
    Write-Host "  Pagine            : $pages"
    Write-Host "  Salvato in        : $DocxPath" -ForegroundColor Green
    Write-Host ""
}
finally {
    if ($doc)  { try { $doc.Close(0) } catch {} }
    if ($word) { try { $word.Quit()  } catch {} }
    foreach ($o in @($doc, $word)) {
        if ($o) { try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($o) } catch {} }
    }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
}
