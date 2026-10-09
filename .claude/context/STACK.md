---
generated-from-commit: d09fa5b4d0c9480c6be04c3b109041484a3e5038
generated-from-branch: main
generated-date: 2026-10-09
covers-paths:
  - '*.ps1'
  - 'config.json'
  - 'export-request.example.json'
  - 'tests/**'
  - 'tools/teams_evidence.py'
  - 'requirements-evidence.txt'
last-verified-commit: d09fa5b4d0c9480c6be04c3b109041484a3e5038
---

# Stack applicativo

Gli script usano Windows PowerShell 5.1, `Invoke-RestMethod` e Microsoft Graph v1.0 con client credentials. Non dipendono dal modulo Microsoft.Graph. Il token resta in memoria. `config.json` è un modello; il file compilato è `config.local.json`, ignorato da git.

`Export-TeamsMessages.ps1` è l'esportatore precedente con modalità Chat, Channel e UserChats, filtri, paginazione, retry e media opzionali. `Get-TeamsIds.ps1` mostra le sorgenti disponibili. `ConvertTo-Docx.ps1` converte un CSV con Microsoft Word via COM; era già presente e non versionato all'avvio della sessione.

`Export-TeamsConversation.ps1` è il percorso aggiunto per una conversazione diretta: verifica la richiesta privata prima dell'accesso, risolve i due utenti anche con ordine nome-cognome invertito, pagina le chat con membri espansi e verifica i membri completi prima di leggere i messaggi. Ordina la richiesta per creazione decrescente e interrompe il recupero prima dell'inizio approvato; ordina gli artefatti cronologicamente in senso crescente. Non chiama l'endpoint `/replies` per ciascun messaggio della chat privata.

Gli output sono HTML statico con testo escaped, TXT, CSV, JSON della copia tecnica e del riepilogo, autorizzazione testuale e impronte SHA-256. Le immagini e gli allegati sono riferimenti; i file non vengono scaricati. Le prove in `tests/Test-TeamsConversation.ps1` simulano HTTP senza credenziali reali.

Gli strumenti Python sotto `tools/` sono copie dal template per memoria, discovery e verifiche documentali; non sono necessari al recupero Graph. La creazione dei documenti compilati Word/PDF in questa sessione ha usato librerie locali già installate, tramite uno script privato. Non è stata introdotta una dipendenza Python nell'esportatore.

`Export-TeamsEvidence.ps1` è l'orchestratore del pacchetto documentato. Chiama l'esportatore Graph, poi `tools/teams_evidence.py` per confronto dei messaggi, archivio tecnico, verbale PDF e manifesti. Python 3.9+ e PyMuPDF 1.25.2+ sono dichiarati in `requirements-evidence.txt`; il recupero semplice resta PowerShell. Le risposte HTTP della conversazione sono conservate senza token, mentre le risposte di ricerca restano nel livello privato. Il tool restituisce percorsi, conteggio e hash del manifesto.
