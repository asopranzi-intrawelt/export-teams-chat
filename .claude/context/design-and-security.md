---
generated-from-commit: d09fa5b4d0c9480c6be04c3b109041484a3e5038
generated-from-branch: main
generated-date: 2026-10-09
covers-paths:
  - '*.ps1'
  - '.gitignore'
  - 'docs/**'
  - 'export-request.example.json'
  - 'tools/teams_evidence.py'
last-verified-commit: d09fa5b4d0c9480c6be04c3b109041484a3e5038
---

# Design e sicurezza

Separare sempre istruzioni dell'operatore e liceità del trattamento. Il percorso ordinario richiede il documento firmato e i presupposti registrati. Il parametro per esecuzione anticipata richiede un ordine scritto separato, vincolato mediante hash a Word e richiesta; conserva Draft e non simula firme o valutazioni. Questa eccezione documenta la decisione tecnica e non certifica la liceità. ADR-007.

Nomi e identificativi reali restano nel livello privato. I vecchi documenti sono stati anonimizzati dopo copia privata; la storia git non è stata riscritta. `output/` e `_notes/` sono ignorati: questa esclusione non cifra i file e non definisce le ACL. L'archivio sicuro, la consegna e la cancellazione sono presupposti operativi da verificare prima dell'uso reale.

Il recupero seleziona chat dirette con esattamente i due membri richiesti e conserva i messaggi del solo periodo approvato. HTML e testo di consultazione conservano contesto e timestamp; il corpo originale resta nella copia tecnica. I dati non vengono inviati a servizi AI. La funzione HTTP del nuovo script invia il bearer token solo a endpoint HTTPS con host Graph previsto.

Gli script precedenti non implementano il nuovo controllo della firma: la documentazione prescrive gli stessi controlli prima del loro uso e vieta usarli per aggirare il nuovo percorso. Una futura estensione automatizzata richiederà una decisione specifica; non sono state aggiunte pianificazioni o nuovi permessi dell'applicazione.

Il modello e i limiti della valutazione sono in `docs/privacy-export.md`. Nessuna manleva assoluta o certificazione di conformità viene promessa.

Il tool documentato verifica ogni messaggio tra risposte Graph, copia tecnica, CSV e HTML; conserva codice e manifesti nell'archivio. Un duplicato discordante interrompe la preparazione. La consegna rilegge i file dalla destinazione e controlla le impronte; il verbale contiene il riscontro dei dati e il registro privato finale comprende tutti e cinque i file. Il confronto con un hash del manifesto conservato separatamente è disponibile nel verificatore. Non vengono acquisiti i file allegati o una storia completa di versioni e cancellazioni; i tempi locali non sono una marcatura qualificata.
