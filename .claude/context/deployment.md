---
generated-from-commit: d09fa5b4d0c9480c6be04c3b109041484a3e5038
generated-from-branch: main
generated-date: 2026-10-09
covers-paths:
  - '*.ps1'
  - '.gitignore'
  - 'tests/**'
  - 'tools/teams_evidence.py'
  - 'requirements-evidence.txt'
last-verified-commit: d09fa5b4d0c9480c6be04c3b109041484a3e5038
---

# Uso reale e ambienti

## Modello di separazione

Il progetto è un insieme di strumenti locali Windows, senza server applicativo, pipeline di deploy o ambiente di staging. Si mantiene il modello esistente: sorgenti nello stesso repository, esecuzione manuale, configurazione reale privata. Le prove introdotte usano dati sintetici e HTTP simulato, così non accedono all'app Graph reale né al contenuto delle conversazioni. Decisione ADR-004.

Eseguita l'acquisizione reale su ordine scritto di procedere prima della firma: una chat, 2.899 messaggi e cinque copie di rete con impronte coincidenti. Stato e percorsi effettivi sono privati. La configurazione compilata esistente e i permessi Graph non sono stati modificati. Nessun contenuto reale è usato nelle prove.

## Esecuzione

La richiesta compilata va nel livello privato. Dopo verifica manuale del documento firmato e dei presupposti, il comando è:

```powershell
.\Export-TeamsConversation.ps1 -RequestPath .\_notes\export-request.local.json
```

Ogni esecuzione usa una cartella nuova sotto `output/`; una cartella già esistente viene rifiutata. Il titolare deve predisporre cifratura, accessi e consegna sicura prima di procedere. I permessi Graph esistenti non vengono ampliati. Non è prevista alcuna pubblicazione degli artefatti.

Per il pacchetto con verbale e consegna usare `Export-TeamsEvidence.ps1`, secondo `docs/teams-evidence.md`. Verifica le dipendenze prima di Graph, conserva il registro privato sotto `_notes/acquisizioni/`, crea cinque file in una cartella nuova e, con `-DestinationRoot`, una sottocartella nuova nella destinazione. Un errore interrompe il flusso, mantiene i riscontri e non viene dichiarato consegnato. Verifica offline del pacchetto con `tools/teams_evidence.py verify`, eventualmente confrontando l'impronta del manifesto conservata separatamente.
