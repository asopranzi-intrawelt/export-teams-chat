# Acquisizione Teams con verbale e verifiche di integrità

`Export-TeamsEvidence.ps1` esegue il recupero di una conversazione diretta, verifica tutti i messaggi e prepara la consegna. Usa `Export-TeamsConversation.ps1` per Graph e `tools/teams_evidence.py` per i controlli locali e il PDF. Il risultato è una cartella di cinque file: `Conversazione.html`, `Conversazione.csv`, `Acquisizione_tecnica.zip`, `Verbale_acquisizione.pdf` e `SHA256.csv`.

Il verbale documenta provenienza, periodo, operatore, strumenti, acquisizione, controlli e consegna. Le impronte attestano la corrispondenza dei file con i riferimenti conservati. Il programma non appone firme digitali o marche temporali qualificate e non certifica il valore probatorio o la liceità del trattamento: il quadro è quello degli artt. 20 CAD e 2712 c.c., con i presupposti privacy descritti in [privacy-export.md](privacy-export.md). I collegamenti normativi sono riportati nel verbale.

## Preparazione

Servono Windows PowerShell 5.1, Python 3.9 o successivo e PyMuPDF. La verifica delle dipendenze avviene prima delle credenziali e delle richieste Graph. Per installare la dipendenza Python:

```powershell
python -m pip install -r requirements-evidence.txt
```

Compilare la configurazione privata e la richiesta come descritto nel [README](../README.md). Nominativi, credenziali, incarichi, dati acquisiti e registri restano fuori dal versionamento. Il percorso ordinario richiede la richiesta approvata e il documento firmato verificato dall'operatore.

```powershell
.\Export-TeamsEvidence.ps1 -RequestPath .\_notes\export-request.local.json
```

Per consegnare su una cartella già esistente, locale o di rete, usare `-DestinationRoot`. Il programma crea una sottocartella con lo stesso nome del pacchetto locale e rifiuta destinazioni o output già esistenti.

```powershell
.\Export-TeamsEvidence.ps1 -RequestPath .\_notes\export-request.local.json -OutputPath '.\output\<pacchetto>' -DestinationRoot '\\<server>\<cartella>'
```

## Istruzione esplicita prima della firma

Quando l'operatore riceve un ordine scritto di procedere prima della sottoscrizione, può registrarlo in un JSON privato separato. La richiesta non viene promossa ad Approved; il riepilogo e il verbale riportano l'assenza di firma e non simulano una verifica giuridica. Il parametro dedicato non sostituisce una base giuridica del trattamento.

```json
{
  "Status": "ExecuteBeforeSignature",
  "Instruction": "<testo esatto dell'ordine ricevuto>",
  "RecordedAtUtc": "<data di registrazione UTC con offset>",
  "DocumentPath": "<percorso assoluto del documento da sottoscrivere>",
  "DocumentSha256": "<SHA-256 del documento>",
  "RequestSha256": "<SHA-256 del JSON della richiesta>"
}
```

Le impronte vanno calcolate sui file effettivi, dopo la compilazione. Modificare successivamente la richiesta o il Word invalida il collegamento all'istruzione. La firma futura non viene retrodatata o registrata come già presente.

```powershell
Get-FileHash -LiteralPath .\_notes\export-request.local.json -Algorithm SHA256
.\Export-TeamsEvidence.ps1 -RequestPath .\_notes\export-request.local.json -ExecutionInstructionPath .\_notes\istruzione.local.json -DestinationRoot '\\<server>\<cartella>'
```

## Acquisizione, verifica e consegna

Prima dei messaggi vengono verificati i due membri della chat. Il recupero mantiene entrambi gli autori, l'intervallo esplicito e l'ordine cronologico. Il confronto locale verifica identificativi, autori, testi, riferimenti alle risposte, corrispondenza degli istanti UTC e locali, periodo e duplicati. Un duplicato con contenuti diversi fa fallire la preparazione: non viene presentato come una copia coerente.

L'archivio conserva le risposte JSON decodificate da PowerShell, il registro delle richieste della sola conversazione, il documento di riferimento, le istruzioni, la versione dell'esportatore utilizzata e le verifiche. Un manifesto interno identifica ogni file dell'archivio. Le risposte usate per la ricerca di account e altre chat sono escluse dalla consegna e restano nel registro privato. La risposta della pagina di confine può contenere messaggi fuori intervallo: il verbale ne riporta il numero; HTML e CSV li escludono.

La consegna avviene in due passaggi. Prima vengono copiati e riletti HTML, CSV e archivio tecnico. Il loro riscontro viene inserito nel verbale, che viene consegnato insieme al manifesto. Infine vengono riletti tutti e cinque i file della destinazione e confrontati con gli originali locali. Il registro finale e la sua impronta restano nella cartella privata dell'operazione, restituita come `WorkPath`.

Il risultato restituisce anche `ManifestSha256`. Conservare questa impronta separatamente dal pacchetto, insieme al verbale sottoscritto e alle istruzioni dell'operazione. Un confronto con un riferimento indipendente protegge anche dal caso in cui vengano modificati file e manifesto insieme.

```powershell
python tools/teams_evidence.py verify --output '.\output\<pacchetto>' --expected-manifest-sha256 '<impronta-conservata>'
```

La firma del fascicolo o del verbale cambia le relative impronte: conservarla come versione successiva e produrre il relativo manifesto, mantenendo intatta la copia acquisita. Per una firma digitale o una marcatura temporale qualificata utilizzare il servizio aziendale previsto e conservare i relativi esiti; il tool non dichiara di averli apposti.

## Errori e limiti

Una verifica fallita interrompe il flusso e lascia il registro privato con lo stato Failed. Un trasferimento incompleto non viene dichiarato consegnato. Conservare il materiale per il riscontro dell'errore e usare una nuova cartella per un'altra acquisizione; il tool non cancella o sovrascrive le prove precedenti.

La completezza riguarda i messaggi disponibili attraverso Graph durante il recupero. Messaggi definitivamente cancellati, versioni non restituite e file allegati non vengono ricostruiti. La lettura non è una transazione congelata del servizio: eventuali modifiche concorrenti possono produrre risposte discordanti e far fallire i controlli. Gli hash non attestano la riservatezza della cartella: accessi, custodia, conservazione e gestione dei backup restano da definire nelle istruzioni aziendali.

## Prove

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-TeamsEvidence.ps1
```

La prova usa soltanto fixture sintetiche e HTTP simulato. Esercita il percorso firmato, quello con istruzione anticipata, la generazione del PDF e dell'archivio, la consegna, le cinque copie, il divieto di sovrascrittura e il rilevamento di un CSV modificato. Il file manomesso viene ripristinato e il suo hash ricontrollato. Le chat reali non sono fixture di test.
