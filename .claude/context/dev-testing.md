---
generated-from-commit: d09fa5b4d0c9480c6be04c3b109041484a3e5038
generated-from-branch: main
generated-date: 2026-10-09
covers-paths:
  - 'tests/**'
  - 'Export-TeamsConversation.ps1'
  - 'Export-TeamsEvidence.ps1'
  - 'requirements-evidence.txt'
  - 'tools/**'
last-verified-commit: d09fa5b4d0c9480c6be04c3b109041484a3e5038
---

# Verifiche

Il test del nuovo esportatore è offline, con nomi e credenziali sintetici e una funzione HTTP sostitutiva che rifiuta URL non previsti. Controlla blocchi della bozza e dei campi incompleti prima della configurazione, verifica del file e dell'hash, ordine cronologico, entrambi gli autori, paginazione e deduplicazione, esclusione di gruppi e altre chat, periodo inclusivo/esclusivo, stop del recupero, ora italiana e cambio di ora legale, paragrafi e escape HTML, riferimento alla risposta e impronte dei file.

La revisione preliminare deve essere un booleano vero, non una stringa non vuota; l'inizio e la fine del periodo devono riportare il fuso. Le prove esercitano esplicitamente anche questi rifiuti prima della configurazione e della rete.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-TeamsConversation.ps1
```

Le fixture producono quattro messaggi inclusi. I dati fuori periodo restano esclusi anche dalla copia tecnica. Il test crea solo cartelle private sotto `_notes/tests/`. La non vacuità del blocco della bozza è verificata su una copia privata del sorgente: rimuovendo la guardia, il test fallisce. Il sorgente originale resta verificato mediante SHA-256.

Per la documentazione e il sistema di progetto eseguire discovery, misura istruzioni, unwrap e controlli delle tabelle e dei comandi. Per i PowerShell eseguire anche il parser. Le prove storiche su Teams riportate in `SVILUPPO.md` mantengono il proprio perimetro. Una chat reale è stata successivamente acquisita e verificata per la consegna richiesta, senza usarne il testo nei test.

I documenti privati Word/PDF sono generati dallo stesso modello; sezioni, nominativi, campi firma e numero di pagine sono stati verificati nel PDF salvato e con anteprime. Nessuna firma è stata aggiunta.

Il fascicolo corrente raccoglie incarico, istruzioni e fonti. La verifica privata confronta le 34 celle dei 15 campi e delle due sottoscrizioni tra Word e PDF, gli otto indirizzi istituzionali dei collegamenti, le fonti incorporate mediante SHA-256 e i 16 file precedenti archiviati senza alterazioni. Controlla inoltre che la cartella di consegna contenga esattamente Word e PDF e che la richiesta resti una bozza. Impaginazione e spazi firma sono verificati nelle tre anteprime. Lo script di estrazione è invariato; le prove tecniche offline già eseguite mantengono il loro perimetro e non costituiscono accesso reale.

Il controllo delle bozze sopra e il successivo riscontro preliminare sono storici dopo l'acquisizione. La verifica privata principale riconosce il registro finale: 2.899 messaggi, archivio e manifesti integri, Word invariato, codice usato conservato, verbale di due pagine e cinque file coincidenti con il riscontro della copia di rete. Firma e verifica giuridica non sono dichiarate acquisite. Le chat reali sono state verificate localmente senza inviarne il testo al modello.

La prova del tool completo usa sole fixture sintetiche e HTTP simulato:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-TeamsEvidence.ps1
```

Esercita i percorsi ordinario e anticipato, la paginazione e i duplicati coerenti, il confronto locale delle viste con le risposte, il PDF e i manifesti, il trasferimento dei cinque file e il divieto di sovrascrittura prima di HTTP. Una modifica reale del CSV deve essere rifiutata; il ripristino è controllato mediante hash. Verificato anche il confronto del manifesto con un'impronta indipendente. Le prove cadono sulle copie mutate che omettono il confronto della richiesta all'istruzione e la verifica del checksum esterno. Sorgenti canonici invariati; test e registri di mutazione privati.
