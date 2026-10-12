# Pendenze

## P-001 - Finalità e presupposti

Stato: aperta dal 2026-10-09, estesa il 2026-10-12, competenza aziendale. L'utente dichiara «controllo dell'attività» e ordina l'esecuzione prima della sottoscrizione. L'export è eseguito, senza certificare determinazioni mancanti su base giuridica, necessità, informative, garanzie lavoristiche e conservazione. Il verbale tecnico non equivale a un esito positivo della verifica giuridica. Nessuna nuova richiesta generica di conferma dell'azione già autorizzata. Dal 2026-10-12 la pendenza riguarda anche il 2024 di Roberta Vergani e il 2025 e il 2024 di Nicolas Pena Ugarte, cioè un secondo interessato e un secondo periodo: per ciascuno valgono le stesse determinazioni mancanti, e il fascicolo del 2025 non le copre.

## P-002 - Firma e registrazione

Stato: aperta dal 2026-10-09, estesa il 2026-10-12, firma successiva annunciata dall'utente. Il documento è preservato, copiato nell'archivio e identificato mediante SHA-256. La richiesta resta Draft; l'istruzione separata registra l'ordine di eseguire prima della firma. Conservare la futura versione sottoscritta con una nuova impronta, senza sovrascrivere la copia acquisita o retrodatare la firma. I documenti da sottoscrivere sono ora quattro: quello del 2025 e i tre prodotti il 2026-10-12 per Vergani 2024, Pena Ugarte 2025 e Pena Ugarte 2024, ciascuno con la propria impronta registrata in `_notes/batch-2026-10-12.json`. Ogni firma vale per il proprio perimetro e produce una versione nuova da conservare accanto a quella acquisita.

## P-003 - Estrazione e consegna effettive

Stato: chiusa il 2026-10-09. Acquisita una chat diretta, membri verificati, 2.899 messaggi del 2025. Consegnati cinque file sulla cartella richiesta; confrontati gli hash delle copie rilette dalla rete con quelli locali. Percorso e riscontri nel registro privato. La verifica della copia non attesta ACL, cifratura o conservazione.

## P-005 - Integrità e provenienza dell'acquisizione

Stato: chiusa per le verifiche tecniche il 2026-10-09. Documentati operatore, perimetro, codice utilizzato, tempi, risposte API e limiti; confrontati tutti i messaggi tra fonte, CSV e HTML, autori, istanti, ordine e unicità. Archivio e manifesti verificati, copie di rete concordanti. Verbale di acquisizione e consegna raccolto in due pagine. Nessuna firma digitale o marca temporale qualificata apposta; il valore nel procedimento resta distinto dai controlli tecnici.

## P-006 - Estrazione e consegna del 2024 e del secondo interessato

Stato: chiusa il 2026-10-12. Acquisite tre conversazioni dirette con membri verificati e consegnate in tre cartelle separate sulla condivisione richiesta: Vergani 2024 con 1.539 messaggi, Pena Ugarte 2025 con 1.919 e Pena Ugarte 2024 con 2.184. Cinque file per cartella, impronte locali e di rete uguali al manifesto, riscontro indipendente in `_notes/verify_batch.py`. Un messaggio del 2024 senza nome del mittente nella fonte è dichiarato nel verbale del terzo pacchetto. La verifica della copia non attesta ACL, cifratura o conservazione, e la chiusura di questa voce riguarda l'esecuzione tecnica, non i presupposti di P-001.

## P-007 - Rimozione delle tre cartelle superate in rete

Stato: chiusa il 2026-10-12 su ordine dell'utente. La prima esecuzione delle tre acquisizioni aveva consegnato verbali con la finalità scritta con l'apostrofo al posto dell'accento; dopo la ripetizione, le tre cartelle superate con timestamp 20261012T082645Z, T082810Z e T083703Z sono state rimosse dalla condivisione con `_notes/remove_superseded.ps1`, che prima riscontra le tre consegne valide confrontando ogni file con il manifesto e con la copia locale, e si ferma se trova una sottocartella inattesa. Nomi, dimensioni e impronte dei quindici file rimossi sono registrati in `_notes/rimozione-superate.json`; le copie locali sotto `output/` sono intatte. Sulla condivisione restano le quattro cartelle attese, una per interessato e anno.

## P-004 - Versionamento manuale e storico

Stato: chiusa il 2026-10-12 con riscontro. L'utente ha eseguito il commit: `e7efaab` «Verificatore: mittente senza nome dichiarato e contato, con prove», autore asopranzi-intrawelt, albero di lavoro pulito dopo il commit; la correzione del verificatore e le due prove che la misurano sono versionate. Gli script dell'operazione, i documenti e i registri restano nel livello privato e fuori da git. Resta valido per il futuro quanto segue: prima di rendere pubblico il repository va valutata anche la storia, che conserva identificativi dei commit precedenti e non è stata riscritta. Storico della voce: aperta dal 2026-10-09, passaggio manuale finale preparato. Codice, prove, guida, dipendenza e memoria pronti; controlli finali confermati. Profilo Git globale esistente rilevato per i comandi proposti, identità locale ancora non impostata, remoto e configurazione invariati. Nessuna attribuzione dedotta dai nominativi dell'export. Le copie correnti sono anonimizzate; gli identificativi nei commit precedenti restano nella storia, non riscritta. Prima di rendere pubblico il repository valutare anche la storia. Commit, push e deploy restano dell'utente per le istruzioni di macchina. Chiudere questa voce solo dopo il riscontro di un commit effettivo. Dal 2026-10-12 attendono il commit anche la correzione del verificatore sul mittente senza nome e le due prove che la misurano, in `tools/teams_evidence.py`, `tests/Test-TeamsConversation.ps1` e `tests/Test-TeamsEvidence.ps1`; gli script dell'operazione e i documenti restano nel livello privato.
