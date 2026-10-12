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
last-verified-commit: 937b2416e3bc9d5b06a91d2d62aa4a0451aa7252
---

# Lavoro corrente

L'export richiesto è completato: una conversazione diretta, entrambi i membri verificati, 2.899 messaggi del 2025 e cinque file consegnati sulla cartella di rete. Verificati tutti i messaggi fra risposte Graph, copia tecnica, CSV e HTML; verificate le impronte delle cinque copie rilette dalla rete. Il verbale di due pagine raccoglie acquisizione, riscontri, fonti e consegna.

La precedente consegna è stata ridotta a un fascicolo unico, secondo ADR-006. I file di autorizzazione sono stati successivamente modificati dall'utente: il Word ricevuto è preservato e la consegna precedente è storico. Non rigenerare i suoi documenti per riallinearli a una vecchia verifica delle bozze.

L'utente ha superato esplicitamente l'attesa della firma: ADR-007 registra l'istruzione anticipata, vincolata mediante hash al documento e alla richiesta. La richiesta resta Draft e il verbale non dichiara presupposti giuridici verificati. Documento dell'utente invariato e versione acquisita conservata. Firma futura da registrare come nuova versione.

Rimossi dai PDF i riferimenti ai progetti locali e alle modalità di consultazione delle fonti, come richiesto. Il precedente riscontro preliminare resta storico e non descrive lo stato successivo dell'export. Dati reali e registri soltanto nel livello privato; nessun testo delle chat inviato al modello o utilizzato nelle fixture.

La richiesta successiva è rendere il flusso un tool e preparare il versionamento. `Export-TeamsEvidence.ps1` gestisce acquisizione, pacchetto di cinque file e consegna; `tools/teams_evidence.py` verifica i dati, genera il PDF e gestisce manifesti e archivio. Dipendenza in `requirements-evidence.txt`, guida in `docs/teams-evidence.md`, prove in `tests/Test-TeamsEvidence.ps1`. Conserva le versioni degli strumenti nell'archivio e restituisce l'impronta del manifesto per un riscontro indipendente. Nessuna firma digitale o marca qualificata automaticamente dichiarata. Commit e push manuali; P-003 e P-005 chiuse, P-001/P-002 aziendali e P-004 versionamento ancora pertinenti.

Il 2026-10-12 sono state eseguite tre nuove acquisizioni nella stessa modalità: Roberta Vergani per il 2024, Nicolas Pena Ugarte per il 2025 e per il 2024, sempre con Alessandro Potalivo come altro interlocutore e con consegna in tre cartelle separate sulla stessa condivisione. Il fascicolo del 2025 non copre questo perimetro e lo dice esso stesso; su ordine esplicito dell'utente è stato replicato l'impianto, con un documento da firmare per ciascun export, la propria richiesta Draft e la propria istruzione anticipata vincolata mediante hash. Nessuna firma o verifica giuridica è dichiarata acquisita e il documento compilato dall'utente resta invariato. Preparazione, esecuzione e riscontro stanno in `_notes/prepare_batch.py`, `_notes/run_batch.ps1` e `_notes/verify_batch.py`; le impronte dei documenti e delle richieste in `_notes/batch-2026-10-12.json`.

I tre pacchetti consegnati contengono 1.539, 1.919 e 2.184 messaggi, una sola chat diretta ciascuno con membri verificati, e sono stati riletti dalla rete con impronte uguali al manifesto. Il terzo ha richiesto una correzione del verificatore: un messaggio del 2024 ha il nome del mittente nullo nella fonte, l'esportatore scrive da sempre «(mittente non disponibile)» e il confronto stretto rifiutava la riga. Ora l'identificativo dell'autore resta confrontato senza eccezioni, il nome viene confrontato con la dicitura soltanto quando la fonte non ne ha, e quei messaggi sono contati nelle verifiche e dichiarati nel verbale. Le tre acquisizioni sono state poi rifatte, su scelta dell'utente, perché le richieste erano state scritte con apostrofi ASCII al posto degli accenti e i verbali riportavano la finalità come «Controllo dell'attivita'». Rigenerare il solo PDF non era una via: il verbale nasce dalla richiesta, vincolata per impronta all'istruzione e copiata dentro l'archivio tecnico. Le consegne valide portano il timestamp 20261012T0854, T0855 e T0856; quelle del primo giro restano in rete e la loro rimozione spetta all'utente. I fascicoli da firmare non sono stati rigenerati e conservano le impronte del primo giro, perché la finalità non vi compare.

Chiusura richiesta dall'utente nella sessione precedente: verificati pacchetto reale, esclusione dei dati privati, stato Git e profilo esistente della macchina. Predisposto il passaggio manuale per identità locale e commit; nessuna modifica alla configurazione, all'indice Git o al remoto eseguita dall'agente. Punto di ripresa e messaggio di commit pronti. La funzione di shell per chiudere è presente, ma il relativo script non è istanziato nel repository: non proporre un comando che qui si fermerebbe senza versionare.
