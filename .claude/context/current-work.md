---
generated-from-commit: d09fa5b4d0c9480c6be04c3b109041484a3e5038
generated-from-branch: main
generated-date: 2026-10-09
covers-paths:
  - '*.ps1'
  - 'docs/**'
  - 'tests/**'
  - 'export-request.example.json'
  - 'tools/teams_evidence.py'
  - 'requirements-evidence.txt'
last-verified-commit: d09fa5b4d0c9480c6be04c3b109041484a3e5038
---

# Lavoro corrente

L'export richiesto è completato: una conversazione diretta, entrambi i membri verificati, 2.899 messaggi del 2025 e cinque file consegnati sulla cartella di rete. Verificati tutti i messaggi fra risposte Graph, copia tecnica, CSV e HTML; verificate le impronte delle cinque copie rilette dalla rete. Il verbale di due pagine raccoglie acquisizione, riscontri, fonti e consegna.

La precedente consegna è stata ridotta a un fascicolo unico, secondo ADR-006. I file di autorizzazione sono stati successivamente modificati dall'utente: il Word ricevuto è preservato e la consegna precedente è storico. Non rigenerare i suoi documenti per riallinearli a una vecchia verifica delle bozze.

L'utente ha superato esplicitamente l'attesa della firma: ADR-007 registra l'istruzione anticipata, vincolata mediante hash al documento e alla richiesta. La richiesta resta Draft e il verbale non dichiara presupposti giuridici verificati. Documento dell'utente invariato e versione acquisita conservata. Firma futura da registrare come nuova versione.

Rimossi dai PDF i riferimenti ai progetti locali e alle modalità di consultazione delle fonti, come richiesto. Il precedente riscontro preliminare resta storico e non descrive lo stato successivo dell'export. Dati reali e registri soltanto nel livello privato; nessun testo delle chat inviato al modello o utilizzato nelle fixture.

La richiesta successiva è rendere il flusso un tool e preparare il versionamento. `Export-TeamsEvidence.ps1` gestisce acquisizione, pacchetto di cinque file e consegna; `tools/teams_evidence.py` verifica i dati, genera il PDF e gestisce manifesti e archivio. Dipendenza in `requirements-evidence.txt`, guida in `docs/teams-evidence.md`, prove in `tests/Test-TeamsEvidence.ps1`. Conserva le versioni degli strumenti nell'archivio e restituisce l'impronta del manifesto per un riscontro indipendente. Nessuna firma digitale o marca qualificata automaticamente dichiarata. Commit e push manuali; P-003 e P-005 chiuse, P-001/P-002 aziendali e P-004 versionamento ancora pertinenti.

Chiusura richiesta dall'utente: verificati pacchetto reale, esclusione dei dati privati, stato Git e profilo esistente della macchina. Predisposto il passaggio manuale per identità locale e commit; nessuna modifica alla configurazione, all'indice Git o al remoto eseguita dall'agente. Punto di ripresa e messaggio di commit pronti. La funzione di shell per chiudere è presente, ma il relativo script non è istanziato nel repository: non proporre un comando che qui si fermerebbe senza versionare.
