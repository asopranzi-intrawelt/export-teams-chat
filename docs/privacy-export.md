# Presupposti per esportare una conversazione Teams

La documentazione aziendale è raccolta in un [fascicolo unico](Fascicolo-export.template.txt): incarico, istruzioni accanto ai campi, sottoscrizioni e riferimenti normativi. I documenti ricevuti dall'utente vengono preservati nella cartella privata di autorizzazione. Il verbale tecnico raccoglie acquisizione, verifiche e consegna; i dati e i registri sono raccolti nell'archivio tecnico. Le versioni precedenti sono conservate nelle note private.

Questo progetto prepara l'estrazione tecnica e le istruzioni firmabili. Non certifica la conformità del trattamento: finalità, base giuridica e proporzionalità dipendono dal caso concreto. Una richiesta del dirigente e i permessi dell'applicazione non sono una base giuridica autonoma. I documenti compilati e firmati restano nel livello privato.

## Autorizzazione e base giuridica

L'autorizzazione alla persona che opera sotto l'autorità del titolare va distinta dal presupposto che rende lecita l'estrazione. L'art. 2-quaterdecies del Codice privacy disciplina l'assegnazione di compiti specifici; la base giuridica va individuata separatamente. L'art. 114 richiama le garanzie dello Statuto dei lavoratori. Si veda il [testo coordinato pubblicato dal Garante](https://www.garanteprivacy.it/codice).

La finalità deve essere concreta; il periodo, i destinatari e la durata delle copie devono essere necessari rispetto a essa. L'intera cronologia non è giustificata dal basso costo dell'operazione. Non viene selezionato automaticamente il legittimo interesse, né la firma di un interlocutore viene trattata come consenso dell'altro. Per i principi di limitazione della finalità, minimizzazione, conservazione e responsabilizzazione si veda il [GDPR, artt. 5 e 6](https://www.garanteprivacy.it/il-testo-del-regolamento). Il testo del Garante è una versione informativa con rettifiche, non sostituisce la pubblicazione nella Gazzetta ufficiale dell'Unione europea.

## Comunicazioni nel lavoro

Quando l'altra partecipante è una lavoratrice o il trattamento riguarda lavoratori, vanno verificati informativa, policy, finalità dei controlli e presupposti dello Statuto. L'art. 4, comma 3, collega l'utilizzo dei dati alle informazioni adeguate sui mezzi e sui controlli e alla disciplina privacy; non basta una autorizzazione del superiore. Si veda il [testo dell'art. 4 su Normattiva](https://www.normattiva.it/atto/caricaDettaglioAtto?atto.articolo.numero=4&atto.codiceRedazionale=070U0300&atto.dataPubblicazioneGazzetta=1970-05-27&qId=&tabID=0.6434533129744249&title=lbl.dettaglioAtto).

Le [linee guida del Garante del 1 marzo 2007](https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/1387522) riguardano posta e Internet e hanno riferimenti normativi storici: vengono usate per inquadrare riservatezza, trasparenza e controlli mirati, non come testo aggiornato del GDPR. Il [provvedimento del 9 ottobre 2025, n. 613](https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/10185435) riguarda posta aziendale e mostra i limiti di accessi indiscriminati e del consenso di un solo interlocutore. L'applicazione di questi criteri a Teams è una valutazione prudenziale per analogia, non una decisione dell'Autorità sul caso di questo progetto. Non sono state consultate policy, informative, contratti o deleghe aziendali; il loro contenuto non viene presunto.

## Presidi tecnici e limiti

La richiesta locale nasce in `Draft`. Il percorso ordinario verifica i campi dell'incarico firmato prima delle credenziali. Un ordine esplicito di procedere prima della sottoscrizione usa `-ExecutionInstructionPath`: documento e richiesta sono vincolati mediante hash all'istruzione. La firma resta assente e la verifica giuridica non viene attestata. L'istruzione documenta la decisione tecnica dell'operatore; non seleziona automaticamente una base giuridica né certifica la liceità.

L'estrazione legge soltanto chat dirette i cui membri coincidono con i partecipanti richiesti, limita i messaggi al periodo e conserva entrambi i mittenti in ordine cronologico. Produce HTML, TXT, CSV, copia dei messaggi restituiti, riepilogo e impronte. Il CSV contiene UTC e offset; le viste leggibili usano il fuso italiano con ora legale. Non vengono scaricati allegati o immagini. Il testo originario resta nella copia tecnica; prima di conservarla va motivata anche la necessità dei metadati ulteriori.

Le impronte non sono una firma digitale, una marca temporale o una certificazione forense. La completezza è limitata ai messaggi disponibili nell'API e all'accesso dell'applicazione. Cancellazioni, retention del servizio, errori di accesso e messaggi non più disponibili non vengono ricostruiti. Permessi Graph già presenti non vengono ampliati.

L'esclusione da git evita il versionamento accidentale e non cifra i file. Le misure di custodia devono essere adeguate ai dati e al rischio, compresi controllo degli accessi, cifratura ove appropriata e gestione delle copie. Il confronto delle impronte dopo la consegna verifica l'integrità della copia e non i permessi della cartella. Conservazione e cancellazione dei backup vanno documentate. Se gli output devono essere usati in giudizio, il legale valuta acquisizione, integrità e modalità di produzione nel caso concreto.

## Tutela dell'operatore

La tutela consiste in un incarico circoscritto, istruzioni documentate, verifica prima dell'accesso, tracciabilità e possibilità di sospendere istruzioni incomplete o irregolari. Il modello non contiene manleve assolute, esoneri penali o rinunce ai diritti degli interessati. Se l'operatore è esterno all'organizzazione, il suo ruolo privacy va verificato separatamente; la qualifica di IT manager non lo determina da sola.

Verifica delle fonti: 2026-10-09. Lo stato della singola estrazione e i nominativi restano nei documenti privati. Nessuna estrazione viene indicata come eseguita finché non lo è realmente.
