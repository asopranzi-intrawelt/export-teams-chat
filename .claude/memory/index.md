# Snapshot del progetto

Branch: `main`. Commit di riferimento: `937b241`, con il lavoro del 2026-10-12 ancora nel working tree. Data: 2026-10-12. Provenienza del sistema: `.claude/template-reference.json`, adozione selettiva.

## Stato delle schede

| Scheda | Riferimento | Stato |
|---|---|---|
| STACK.md | d09fa5b | Letta sul codice e aggiornata con le modifiche non committate |
| design-and-security.md | d09fa5b | Presupposti, separazione privata e limiti documentati |
| deployment.md | d09fa5b | Uso locale esistente e prove sintetiche documentati |
| dev-testing.md | 937b241 | Prove offline estese al mittente senza nome |
| current-work.md | 937b241 | Tre nuove consegne verificate e correzione del verificatore |
| roadmap.md | d09fa5b | Lavoro tecnico completato; chiusura preparata |

## Punto di ripresa

L'utente ha ordinato esplicitamente di procedere prima della firma e di consegnare sulla cartella del fascicolo. Istruzione registrata separatamente secondo ADR-007; la richiesta resta Draft e la firma non è simulata. Acquisiti e verificati 2.899 messaggi del 2025, con entrambi gli autori. Consegnati cinque file: HTML, CSV, archivio tecnico, verbale di due pagine e manifesto. Riletti tutti i file dalla rete: checksum identici agli originali locali. Le risposte della sola conversazione sono conservate; quelle relative alla ricerca di altre chat sono escluse dalla consegna.

Su ulteriore richiesta dell'utente il flusso diventa un tool del progetto: `Export-TeamsEvidence.ps1`, verificatore e generatore PDF in `tools/teams_evidence.py`, dipendenza dichiarata e prove sintetiche complete. Acquisizione reale e dati dei test restano separati. Il tool non certifica conformità, firma o data certa; conserva codice e riscontri per ricostruire l'operazione. Riferimenti ai progetti locali e modalità di consultazione delle fonti rimossi dai PDF. Documenti dell'utente invariati. Restano P-001 valutazione giuridica, P-002 firma successiva e P-004 versionamento manuale; acquisizione e verifiche tecniche chiuse.

I nominativi, i documenti compilati e la configurazione effettiva sono nel livello privato. Le copie correnti dei vecchi documenti sono state anonimizzate; la storia git conserva i vecchi valori. Commit e push competono all'utente.

Il 2026-10-12 l'utente chiede di ripetere l'export per il 2024 di Roberta Vergani e per il 2025 e il 2024 di Nicolas Pena Ugarte, con lo stesso interlocutore Alessandro Potalivo e tre cartelle separate sulla stessa condivisione. Il fascicolo esistente copre il solo 2025 di Vergani e chiede una nuova valutazione al cambiare di periodo o interessato: su ordine esplicito dell'utente l'impianto è stato replicato, con un documento da firmare per ciascun export, la propria richiesta Draft e la propria istruzione anticipata vincolata mediante hash (ADR-008). Consegnati e verificati tre pacchetti di cinque file: 1.539, 1.919 e 2.184 messaggi, impronte locali e di rete coincidenti. Un messaggio del 2024 senza nome del mittente nella fonte ha fermato la terza verifica: il verificatore ora riconosce la dicitura delle viste, conta quei messaggi e li dichiara nel verbale, mentre l'identificativo dell'autore resta confrontato senza eccezioni (ADR-009). Le tre acquisizioni sono state rifatte nello stesso giro perché i primi verbali riportavano la finalità con l'apostrofo al posto dell'accento, difetto introdotto dall'agente e segnalato prima di qualunque rimedio; valgono le consegne con timestamp 20261012T0854, T0855 e T0856. P-006 chiusa per l'esecuzione tecnica; P-007 aperta per la rimozione delle tre cartelle superate, che spetta all'utente; P-001 e P-002 valgono ora anche per il nuovo perimetro e per tre documenti ancora da firmare.

Nella sessione precedente l'utente aveva chiesto il versionamento e la chiusura. Controlli finali confermati, messaggio di commit pronto e punto di ripresa salvato. Rilevato il profilo Git globale esistente per proporre i comandi manuali di configurazione locale; nessun valore identitario riportato nei file versionabili. Non esiste uno script di chiusura istanziato nel progetto: la funzione di shell presente non può sostituirlo. Ultimo passaggio: configurazione locale e commit nel terminale dell'utente. Non indicare un commit come eseguito prima del riscontro.
