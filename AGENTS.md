# Istruzioni per Codex

Questo progetto adotta il sistema condiviso di istruzioni e memoria del template. Leggere `CLAUDE.md` per intero prima di operare: è la fonte canonica anche per Codex. Leggere le tre regole sempre attive sotto `.claude/rules/`.

All'inizio della sessione eseguire `python tools/sync-codex-skills.py --check` e `python tools/verifica-ripresa.py`, poi leggere `.claude/memory/index.md` e le sole schede pertinenti. Le skill canoniche sono in `.claude/skills/`; `.agents/skills/` contiene soltanto wrapper di discovery.

Aggiornare memoria, contesto e `_notes/RESUME-PROMPT.md` nello stesso giro di lavoro. Preparare `_notes/COMMIT-MSG.txt` con una riga di massimo 72 caratteri. Commit, push e deploy restano manuali. Non includere firme o attribuzioni ad agenti nei commit.

Il percorso ordinario richiede documento firmato e presupposti verificati. Se l'utente ordina esplicitamente l'esecuzione prima della firma, registrare l'istruzione separata e usare il parametro dedicato senza simulare firme, stato Approved o verifica giuridica. Una richiesta tecnica non certifica la liceità. Non leggere contenuti Teams per provare il codice; usare dati sintetici. Nomi, identificativi, credenziali e documenti firmati restano nel livello privato ignorato da git.
