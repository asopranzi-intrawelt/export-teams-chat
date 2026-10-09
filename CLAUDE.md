# export-teams-chat

Script PowerShell per esportare messaggi Teams tramite Microsoft Graph. Questo progetto adotta selettivamente il sistema del template: istruzioni condivise, memoria e contesto, regole di base, skill normative e strumenti locali di verifica. La provenienza e il perimetro sono in `.claude/template-reference.json`; non è dichiarata la copia integrale del bundle.

## Ripresa

Eseguire `python tools/sync-codex-skills.py --check` e `python tools/verifica-ripresa.py`. Leggere `.claude/memory/index.md`, poi `.claude/context/current-work.md` e le sole schede pertinenti. Leggere `.claude/rules/chat-non-e-memoria.md`, `.claude/rules/interaction-style.md` e `.claude/rules/git-commands-format.md` anche in Codex.

## Memoria e contesto

La memoria canonica è `.claude/memory/index.md`, con registro cronologico in `progress.md`, decisioni in `decisions.md` e pendenze in `pending.md`. Le schede tecniche sono `.claude/context/STACK.md`, `design-and-security.md`, `deployment.md`, `dev-testing.md`, `current-work.md` e `roadmap.md`. `SVILUPPO.md` conserva lo storico tecnico e `CONTINUA.md` rimanda al nuovo punto di ripresa.

Aggiornare memoria e contesto nel giro in cui nasce il contenuto. Gli appunti privati e il prompt di ripresa vivono sotto `_notes/`, ignorato da git. Prima della consegna rileggere i contenuti scritti e dichiarare i file aggiornati. Lo standard di riferimento è `.claude/PROJECT-SYSTEM.md`.

## Regole del progetto

La finalità dell'estrazione e la base giuridica competono al titolare del trattamento. L'operatore IT esegue istruzioni documentate nel perimetro richiesto. Bozze, ruoli dirigenziali e permessi Graph non sostituiscono la verifica dei presupposti. Il percorso ordinario attende la firma. L'ordine esplicito dell'utente di procedere prima della firma si registra in un'istruzione privata separata: la richiesta resta `Status=Draft`, senza dichiarare verifiche o firme non acquisite. Decisione ADR-007.

`Export-TeamsConversation.ps1` è il percorso per le nuove estrazioni dirette. Senza parametri aggiuntivi controlla il fascicolo firmato e i presupposti prima delle credenziali. `-ExecutionInstructionPath` richiede invece l'ordine esplicito di esecuzione anticipata, collegato mediante hash al documento e alla richiesta; registra lo stato non firmato. `-EvidencePath` conserva risposte Graph e registro HTTP, senza token. Gli script precedenti non vanno usati per aggirare questi controlli.

`Export-TeamsEvidence.ps1` riunisce recupero, verifiche sui messaggi, verbale PDF, archivio tecnico, manifesti e consegna con rilettura di cinque file. Lo stato della singola acquisizione è privato; codice, dipendenza PDF e prove sintetiche sono versionabili. Per uso e limiti leggere `docs/teams-evidence.md`.

Tutti i dati identificanti e i contenuti estratti restano in `config.local.json`, `_notes/` e `output/`, ignorati da git. Nei documenti candidati al versionamento usare segnaposto fra parentesi angolari. Le prove usano esclusivamente dati sintetici e HTTP simulato. Il CSV conserva UTC; le viste leggibili riportano ora italiana e offset, con entrambi i mittenti in ordine cronologico.

## Skill caricate quando servono

Per verificare il drift delle schede usare `sync-context`; per riprendere il lavoro `riprendi`; per una fotografia del repository `repo-status`. Per scrivere prove o aggiungere guardie leggere `prove-che-misurano` e il suo `RIFERIMENTO.md`. Se una fonte non è recuperabile leggere `fonti-non-recuperabili`. Se cambiano gli alberi di lavoro usare `alberi-di-lavoro`. Se cambia la separazione fra prove e uso reale usare `separazione-ambienti`. Per identità git e remoti usare `identita-git`.

## Chiusura

Eseguire le verifiche pertinenti e aggiornare `_notes/RESUME-PROMPT.md`; registrare l'impronta con `python tools/verifica-ripresa.py --registra`. Preparare `_notes/COMMIT-MSG.txt`, una riga di massimo 72 caratteri. Le operazioni git e i rilasci sono sempre manuali. L'identità git e gli account della macchina mantengono la configurazione esistente.
