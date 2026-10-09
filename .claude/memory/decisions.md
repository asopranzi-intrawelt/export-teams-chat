# Decisioni

## ADR-007 - Esecuzione su istruzione esplicita prima della firma

Data: 2026-10-09. L'utente ordina l'export e la consegna in rete, precisa che apporrà successivamente le firme e chiede di eliminare dalla documentazione i riferimenti ai progetti locali e alle modalità di consultazione delle fonti. L'ordine supera l'attesa operativa di ADR-002 per questo caso. Il percorso ordinario firmato resta disponibile; il parametro dedicato accetta una separata istruzione documentata, vincolata mediante hash alla richiesta e al Word. Lo stato Draft, l'assenza di firma e la verifica giuridica non attestata restano espliciti. Nessun campo Approved o verifica umana viene simulato. Dati reali usati soltanto per l'acquisizione richiesta e per controlli locali, senza inviare testi al modello. La consegna riunisce il risultato in cinque file, con archivio tecnico e verbale unico; nessun riferimento ai progetti normativi locali nei documenti consegnati.

## ADR-006 - Un solo fascicolo da compilare

Data: 2026-10-09. L'utente ha segnalato che la cartella di autorizzazione era caotica. Si raccolgono incarico, istruzioni e fonti in un solo fascicolo: Word modificabile e PDF, senza guide separate, copie TXT o ZIP nella consegna. Le istruzioni stanno accanto ai campi; i codici della revisione precedente vengono rimossi. Le due copie integrali delle fonti e la provenienza sono incorporate nel PDF. Le versioni precedenti sono spostate nell'archivio privato, senza cancellazioni. Questa decisione sostituisce l'impostazione documentale di ADR-005; finalità, verifiche e firma restano da acquisire.

## ADR-005 - Documenti aziendali e guida di compilazione

Data: 2026-10-09. Su richiesta dell'utente, autorizzazione e nota adottano un registro aziendale diretto, con responsabilità e condizioni esplicite e senza ripetere le avvertenze. Applicate le indicazioni di scrittura e la guida anti-slop del template. I campi del modulo hanno codici stabili e una guida indica chi li compila, le informazioni richieste e gli schemi da adattare ai fatti. Gli esempi non sostituiscono la finalità effettiva, ancora ignota. Allegato normativo con fonti primarie e copie informative del GDPR e del Codice privacy; le fonti e i loro limiti restano distinti dalla valutazione aziendale. Nessuna modifica al codice di estrazione o allo stato Draft.

## ADR-001 - Adozione selettiva del sistema di progetto

Data: 2026-10-09. La richiesta è allineare il progetto nelle parti utili. Si adottano istruzioni condivise, memoria versionata, regole di base, strumenti locali e skill normative. Nessun pacchetto di stack, server MCP aggiuntivo o modifica degli account è necessario all'export. La provenienza è registrata senza dichiarare un allineamento integrale del bundle.

## ADR-002 - Istruzioni firmate prima dell'export

Data: 2026-10-09. L'utente ha chiarito che l'autorizzazione deve ancora essere firmata. Si prepara un documento compilabile e si mantiene la richiesta in `Draft`. L'operatore tecnico non conosce la finalità; il richiedente deve dichiararla e il titolare deve verificare base giuridica e necessità. La firma autorizza un incarico delimitato e non certifica da sola la liceità del trattamento. L'estrazione resta in sospeso.

## ADR-003 - Periodo esplicito e contesto della conversazione

Data: 2026-10-09. Si preservano entrambi i mittenti della chat diretta e l'ordine cronologico, senza filtro su un solo autore. Il 2025 è il periodo proposto su indicazione dell'utente, da motivare e confermare dal firmatario. La richiesta di tutta la cronologia non diventa un'impostazione automatica perché la finalità è ancora ignota. Gli intervalli hanno inizio inclusivo e fine esclusiva con offset.

## ADR-004 - Prove separate dai dati reali

Data: 2026-10-09. Il progetto è uno strumento locale già esistente con app Graph di produzione. Si conserva un solo albero di sorgenti e si verificano le nuove funzioni con HTTP simulato e dati sintetici; nessuna nuova infrastruttura o branch di ambiente. L'uso reale avviene manualmente dopo la firma, con dati e credenziali privati. La separazione riguarda soprattutto l'origine dei dati e il divieto di usare chat reali come fixture.
