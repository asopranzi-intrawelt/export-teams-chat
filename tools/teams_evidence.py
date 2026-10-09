"""Verifica e documenta un'acquisizione Teams; non si connette a Graph."""
from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
from hashlib import sha256
from html import escape, unescape
import json
from pathlib import Path
import re
import shutil
import sys
import unicodedata
from urllib.parse import unquote, urlparse
import zipfile

import fitz

ARTIFACTS = {'Conversazione.html', 'Conversazione.csv', 'Acquisizione_tecnica.zip', 'Verbale_acquisizione.pdf', 'SHA256.csv'}
REFERENCES = (
    ('CAD, art. 20', 'https://def.giustiziatributaria.gov.it/DocTribFrontend/executePrintArticolo.do?articolo=Articolo+20&codiceOrdinamento=0000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000&id=%7B263C3642-90D1-44B6-9D9D-0129165C9324%7D'),
    ('Codice civile, art. 2712', 'https://def.giustiziatributaria.gov.it/DocTribFrontend/executePrintArticolo.do?codiceOrdinamento=0000000000027120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000&id=%7BC8475535-0D72-4F0B-B968-8CB43A5A6377%7D&idAttoNormativo=%7B9E93F1BE-06AE-4F24-8E9D-B838F7E0C2E6%7D'),
    ('Statuto dei lavoratori, art. 4', 'https://www.normattiva.it/atto/caricaDettaglioAtto?atto.articolo.numero=4&atto.codiceRedazionale=070U0300&atto.dataPubblicazioneGazzetta=1970-05-27'),
    ('GDPR, artt. 5, 6, 29 e 32', 'https://www.garanteprivacy.it/il-testo-del-regolamento'),
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


def digest(data):
    return sha256(data).hexdigest()


def instant(value):
    return datetime.fromisoformat(re.sub(r'\s([+-]\d{2}:\d{2})$', r'\1', value.replace('Z', '+00:00')))


def body_text(message):
    if message.get('deletedDateTime'):
        return '[messaggio eliminato; testo non disponibile]'
    body = message['body']
    value = body.get('content') or ''
    if body['contentType'] == 'html':
        value = re.sub(r'<img\b[^>]*>', '[immagine inline]', value, flags=re.I | re.S)
        value = re.sub(r'<br\s*/?>|</(?:p|div|li|blockquote|tr)\s*>', '\n', value, flags=re.I | re.S)
        value = unescape(re.sub(r'<[^>]*>', '', value, flags=re.I | re.S)).strip()
    return value or '[messaggio senza testo]'


def norm(value):
    return value.replace('\r\n', '\n')


def validate_acquisition(work):
    export = work / 'export'
    run = read_json(work / 'esito.json')
    require(run['Status'] == 'Acquired', 'Acquisizione non completata.')
    request = read_json(work / 'richiesta.json')
    summary = read_json(export / 'riepilogo.json')
    document = work / ('documento' + run['ReferenceDocumentExtension'])
    require(digest(document.read_bytes()).upper() == summary['ReferenceDocumentSha256'].upper(), 'Documento di riferimento non conforme.')
    require(digest((work / 'Export-TeamsConversation.ps1').read_bytes()).upper() == run['ExporterSha256'], 'Versione dell’esportatore non conforme.')
    require(digest((work / 'Export-TeamsEvidence.ps1').read_bytes()).upper() == run['EvidenceToolSha256'], 'Versione del tool non conforme.')
    require(digest((work / 'teams_evidence.py').read_bytes()).upper() == run['EvidenceHelperSha256'], 'Versione del verificatore non conforme.')
    require(digest(Path(__file__).read_bytes()).upper() == run['EvidenceHelperSha256'], 'Il verificatore è cambiato durante l’acquisizione.')
    if (work / 'istruzione.json').exists():
        instruction = read_json(work / 'istruzione.json')
        require(digest((work / 'istruzione.json').read_bytes()).upper() == summary['ExecutionInstructionSha256'], 'Istruzione di esecuzione non conforme.')
        require(digest((work / 'richiesta.json').read_bytes()).upper() == instruction['RequestSha256'].upper(), 'Richiesta diversa dall’istruzione.')
        require(digest(document.read_bytes()).upper() == instruction['DocumentSha256'].upper(), 'Documento diverso dall’istruzione.')
    for item in csv.DictReader((export / 'sha256.csv').open(encoding='utf-8-sig', newline='')):
        require(Path(item['File']).name == item['File'], 'Percorso non valido nel manifesto originario.')
        require(digest((export / item['File']).read_bytes()).upper() == item['Hash'], 'Impronta originaria non conforme.')
    start, end = instant(request['StartDate']), instant(request['EndDateExclusive'])
    require(start < end and start.tzinfo is not None and end.tzinfo is not None, 'Intervallo non valido.')
    rows = list(csv.DictReader((export / 'messaggi.csv').open(encoding='utf-8-sig', newline='')))
    original = read_json(export / 'originale.json')
    raw = {}
    duplicates = 0
    for chat in original:
        for message in chat['Messages']:
            if message['messageType'] != 'message':
                continue
            key = (chat['ChatId'], message['id'])
            if key in raw:
                require(raw[key] == message, 'Duplicato con contenuti diversi.')
                duplicates += 1
            raw[key] = message
    require(len(rows) == len(raw) == summary['MessageCount'] and rows, 'Conteggi non conformi.')
    require(len({(r['ChatId'], r['MessageId']) for r in rows}) == len(rows), 'Duplicati nel CSV.')
    require([instant(r['Data']) for r in rows] == sorted(instant(r['Data']) for r in rows), 'Ordine cronologico non conforme.')
    require(all(start <= instant(r['Data']) < end for r in rows), 'Messaggio fuori intervallo.')
    participant_ids = {p['UserId'] for p in summary['Participants']}
    require({r['UserId'] for r in rows} <= participant_ids, 'Autore diverso dai partecipanti.')
    html = (export / 'conversazione.html').read_text(encoding='utf-8-sig')
    articles = re.findall(r'<article\b[^>]*id="message-(\d+)"[^>]*>(.*?)</article>', html, re.S)
    require(len(articles) == len(rows), 'Numero di messaggi HTML non conforme.')
    for index, (row, (ordinal, article)) in enumerate(zip(rows, articles), 1):
        msg = raw.get((row['ChatId'], row['MessageId']))
        require(msg is not None, 'Messaggio CSV non presente nella fonte.')
        require(ordinal == str(index), 'Ordine HTML non conforme.')
        require(instant(row['Data']) == instant(msg['createdDateTime']) == instant(row['TimestampLocale']), 'Timestamp non conforme alla fonte.')
        require(row['UserId'] == msg['from']['user']['id'] and row['Mittente'] == msg['from']['user']['displayName'], 'Autore non conforme alla fonte.')
        require(row['ParentId'] == (msg.get('replyToId') or ''), 'Riferimento alla risposta non conforme.')
        require(norm(row['Testo']) == norm(body_text(msg)), 'Testo CSV non conforme alla fonte.')
        rendered = re.search(r'<p class="text">(.*?)</p>', article, re.S)
        sender = re.search(r'<strong>(.*?)</strong>', article, re.S)
        timestamp = re.search(r'<time>(.*?)</time>', article, re.S)
        require(rendered and sender and timestamp, 'Messaggio HTML incompleto.')
        require(norm(unescape(rendered.group(1))) == norm(row['Testo']), 'Testo HTML non conforme al CSV.')
        require(unescape(sender.group(1)) == row['Mittente'] and unescape(timestamp.group(1)) == row['TimestampLocale'], 'Autore o timestamp HTML non conformi.')
    log = [json.loads(line) for line in (work / 'http/richieste.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    selected, source_messages = [], {}
    boundary, members = 0, 0
    for entry in log:
        response = work / 'http' / entry['Response']
        require(response.resolve().is_relative_to((work / 'http').resolve()), 'Percorso risposta non valido.')
        require(digest(response.read_bytes()).upper() == entry['Sha256'] and entry['StatusCode'] == 200, 'Risposta Graph non conforme.')
        uri = urlparse(entry['Uri'])
        require(uri.scheme == 'https' and uri.hostname == 'graph.microsoft.com', 'Endpoint non valido nel registro.')
        parts = unquote(urlparse(entry.get('CollectionUri') or entry['Uri']).path).split('/')
        if len(parts) != 5 or parts[2] != 'chats' or parts[3] not in summary['ChatIds'] or parts[4] not in ('members', 'messages'):
            continue
        selected.append(entry)
        payload = read_json(response)
        if parts[4] == 'members':
            require(len(payload['value']) == 2 and {m['userId'] for m in payload['value']} == participant_ids, 'Membri della chat non conformi.')
            members += 1
        else:
            for msg in payload['value']:
                if not start <= instant(msg['createdDateTime']) < end:
                    boundary += 1
                    continue
                if msg['messageType'] == 'message':
                    key = (parts[3], msg['id'])
                    require(key not in source_messages or source_messages[key] == msg, 'Risposte discordanti per lo stesso messaggio.')
                    source_messages[key] = msg
    require(members == len(summary['ChatIds']) and source_messages == raw, 'Risposte HTTP e copia tecnica non coincidono.')
    checks = {
        'VerifiedAtUtc': datetime.now(timezone.utc).isoformat(), 'MessageCount': len(rows),
        'MessageCounts': summary['MessageCounts'], 'ChatCount': len(summary['ChatIds']),
        'RawDuplicateCount': duplicates, 'UniqueMessageKeys': len(raw),
        'ParticipantsVerified': True, 'ChronologicalOrderVerified': True, 'PeriodVerified': True,
        'UtcAndLocalInstantsMatch': True, 'CsvAndRenderedTextMatchSource': True,
        'RawResponseMessagesMatchTechnicalCopy': True, 'SavedResponseHashesVerified': True,
        'SelectedResponseCount': len(selected), 'DiscoveryResponsesExcluded': len(log) - len(selected),
        'BoundaryMessagesInResponseArchive': boundary,
        'ToolVersions': {'Python': sys.version.split()[0], 'PyMuPDF': fitz.VersionBind},
    }
    (work / 'verifiche.json').write_bytes(json_bytes(checks))
    return request, summary, checks, run, selected


def write_manifest(output):
    with (output / 'SHA256.csv').open('w', encoding='utf-8-sig', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=['File', 'Bytes', 'SHA256'])
        writer.writeheader()
        for path in sorted(output.iterdir()):
            if path.name != 'SHA256.csv':
                require(path.is_file() and path.name in ARTIFACTS, 'File inatteso nel pacchetto.')
                writer.writerow({'File': path.name, 'Bytes': path.stat().st_size, 'SHA256': digest(path.read_bytes())})


def create_report(work, output):
    request = read_json(work / 'richiesta.json')
    summary = read_json(work / 'export/riepilogo.json')
    checks, run = read_json(work / 'verifiche.json'), read_json(work / 'esito.json')
    receipt_path = work / 'consegna-dati.json'
    receipt = read_json(receipt_path) if receipt_path.exists() else None
    if receipt:
        require(receipt['Status'] == 'Verified' and len(receipt['Files']) == 3, 'Consegna dei dati non verificata.')
        for item in receipt['Files']:
            require(digest((output / item['File']).read_bytes()).upper() == item['SHA256'], 'Dati cambiati dopo la consegna.')
    h = '<h1>VERBALE DI ACQUISIZIONE</h1><p class="subtitle">Conversazione Microsoft Teams | Riservato</p><h2>Oggetto e istruzioni</h2>'
    h += f'<p>{escape(request["Participant1"])} / {escape(request["Participant2"])}.<br>Finalità dichiarata: {escape(request["Purpose"])}.<br>Intervallo: {escape(request["StartDate"])} incluso; {escape(request["EndDateExclusive"])} escluso.</p>'
    h += f'<p>{escape(summary["AuthorizationSource"])}. La verifica giuridica e i poteri del firmatario non sono certificati dal programma.</p>'
    h += f'<p class="hash">Documento di riferimento SHA-256:<br>{summary["ReferenceDocumentSha256"].lower()}</p>'
    h += '<h2>Acquisizione e risultato</h2><table>'
    details = (
        ('Messaggi', str(summary['MessageCount'])),
        ('Autori', '; '.join(f'{item["Name"]}: {item["Count"]}' for item in summary['MessageCounts'])),
        ('Conversazioni', str(len(summary['ChatIds'])) + ' chat dirette; membri verificati'),
        ('Primo / ultimo UTC', summary['FirstTimestampUtc'] + ' / ' + summary['LastTimestampUtc']),
        ('Fuso delle viste', summary['TimeZoneId']),
        ('Acquisizione UTC', run['StartedAtUtc'] + ' / ' + run['EndedAtUtc']),
        ('Esecuzione', f'Account Windows: {run["Operator"]}; computer: {run["Machine"]}; PowerShell {run["PowerShellVersion"]}'),
    )
    for label, value in details:
        h += f'<tr><td class="label">{escape(label)}</td><td>{escape(value)}</td></tr>'
    h += '</table><h2>Verifiche di integrità</h2><p>Confrontati tutti i messaggi fra risposte Graph, copia tecnica JSON, CSV e conversazione HTML. Verificati identificativi, autori, testo, riferimenti alle risposte, timestamp, periodo, ordine cronologico e assenza di duplicati nelle viste. Gli istanti UTC e locali coincidono.</p>'
    h += f'<p>Risposte conservate della sola conversazione: {checks["SelectedResponseCount"]}. Le risposte di ricerca relative ad account o altre chat sono escluse dalla consegna. Eventuali messaggi fuori intervallo nelle pagine di confine: {checks["BoundaryMessagesInResponseArchive"]}; restano nel JSON della risposta e sono esclusi da HTML e CSV.</p>'
    h += '<p>Verificate le impronte SHA-256 del documento, del codice utilizzato, dei dati esportati e delle risposte salvate. L’archivio tecnico contiene il registro delle richieste, i metadati HTTP disponibili e un manifesto interno. SHA256.csv identifica i quattro artefatti della consegna.</p>'
    h += '<h2>Consegna e custodia</h2>'
    if receipt:
        h += f'<p>Destinazione: {escape(receipt["Destination"])}.<br>Riscontro UTC: {escape(receipt["VerifiedAtUtc"])}. HTML, CSV e archivio tecnico copiati e riletti: le impronte coincidono con le copie locali.</p>'
        h += '<p>Il registro della copia dei dati è incorporato in questo verbale. Il controllo successivo comprende anche verbale e manifesto e viene conservato nel registro finale dell’operazione.</p>'
    else:
        h += '<p>Pacchetto predisposto localmente. Nessuna consegna è attestata. La verifica delle copie deve essere eseguita dopo ogni trasferimento.</p>'
    h += '<p>Destinatari indicati nella richiesta: ' + escape(request.get('Recipients') or 'non definiti') + '. Conservazione: ' + escape(request.get('RetentionUntil') or 'non definita nella richiesta') + '. Limitare l’accesso agli incaricati; gestire copie e conservazione secondo le istruzioni aziendali.</p>'
    h += '<h2>Limiti dell’acquisizione</h2><p>La copia rappresenta quanto restituito da Graph al momento del recupero. Non ricostruisce messaggi definitivamente cancellati o versioni precedenti non disponibili. Gli allegati non sono scaricati: restano i riferimenti. I JSON HTTP sono contenuti decodificati da PowerShell e salvati in UTF-8, non una cattura dei pacchetti di rete.</p>'
    h += '<p>Gli hash consentono confronti di integrità. Non sono state apposte una firma digitale o una marca temporale qualificata; i tempi derivano dall’orologio del sistema e dai metadati HTTP. La firma successiva del fascicolo produce una nuova versione da conservare con una nuova impronta, senza sostituire il documento acquisito.</p>'
    h += '<h2>Riferimenti normativi</h2>'
    for title, url in REFERENCES:
        h += f'<p class="source"><a href="{escape(url, quote=True)}">{escape(title)}</a></p>'
    h += '<p>Il valore probatorio viene valutato secondo le condizioni dell’art. 20 CAD e dell’art. 2712 c.c. Questo verbale documenta l’operazione tecnica e non certifica la liceità del trattamento.</p><h2>Sottoscrizione dell’operatore</h2><p>Nome ______________________________ Data ____________________<br>Firma _________________________________________________________</p>'
    css = 'body{font-family:sans-serif;font-size:10pt;line-height:1.17;color:#26333d}h1{font-size:18pt;margin:0 0 8pt;color:#1c3448}h2{font-size:11pt;margin:13pt 0 6pt}p{margin:0 0 7pt}.subtitle{font-size:9pt;color:#52616b}.hash{font-family:monospace;font-size:8pt}table{border-collapse:collapse;width:100%;font-size:9pt}td{border:0.4pt solid #cbd1d5;padding:5pt;vertical-align:top}.label{width:25%;background:#f3f5f6}.source{font-size:8.5pt;margin:0 0 4pt}a{color:#234b6d}'
    story = fitz.Story(html='<html><body>' + h + '</body></html>', user_css=css)
    rect = fitz.paper_rect('a4')
    pdf = story.write_with_links(lambda i, f: (rect, fitz.Rect(54, 58, rect.width - 54, rect.height - 52), None))
    for index, page in enumerate(pdf, 1):
        page.insert_text((54, 31), 'ACQUISIZIONE TEAMS | DOCUMENTO RISERVATO', fontsize=8)
        page.insert_text((54, rect.height - 26), f'Verbale tecnico | {index}/{len(pdf)}', fontsize=8)
    if receipt:
        pdf.embfile_add('consegna-dati.json', receipt_path.read_bytes(), filename='consegna-dati.json')
    pdf.embfile_add('verifiche.json', (work / 'verifiche.json').read_bytes(), filename='verifiche.json')
    pdf.set_metadata({'title': 'Verbale di acquisizione Microsoft Teams', 'author': '', 'subject': 'Acquisizione, integrità e consegna'})
    path = output / 'Verbale_acquisizione.pdf'
    path.write_bytes(pdf.tobytes(garbage=4, deflate=True))
    pdf.close()
    with fitz.open(path) as saved:
        text = unicodedata.normalize('NFKC', '\n'.join(p.get_text() for p in saved))
        require(str(summary['MessageCount']) in text, 'Verbale privo del risultato.')
        require(saved.embfile_get('verifiche.json') == (work / 'verifiche.json').read_bytes(), 'Verifiche PDF non conformi.')
        require({link['uri'] for page in saved for link in page.get_links() if 'uri' in link} == {url for _, url in REFERENCES}, 'Riferimenti PDF non conformi.')
    write_manifest(output)


def package_acquisition(work, output):
    require(not output.exists(), 'Cartella di output esistente.')
    request, summary, checks, run, selected = validate_acquisition(work)
    output.mkdir(parents=True)
    shutil.copyfile(work / 'export/conversazione.html', output / 'Conversazione.html')
    shutil.copyfile(work / 'export/messaggi.csv', output / 'Conversazione.csv')
    files = {name: (work / name).read_bytes() for name in ('richiesta.json', 'esito.json', 'verifiche.json', 'Export-TeamsConversation.ps1', 'Export-TeamsEvidence.ps1', 'teams_evidence.py')}
    for name in ('originale.json', 'riepilogo.json'):
        files[name] = (work / 'export' / name).read_bytes()
    doc_name = 'documento' + run['ReferenceDocumentExtension']
    files[doc_name] = (work / doc_name).read_bytes()
    if (work / 'istruzione.json').exists():
        files['istruzione.json'] = (work / 'istruzione.json').read_bytes()
    files['richieste.jsonl'] = ('\n'.join(json.dumps(entry, ensure_ascii=False) for entry in selected) + '\n').encode('utf-8')
    for entry in selected:
        files[entry['Response']] = (work / 'http' / entry['Response']).read_bytes()
    manifest = [{'File': name, 'Bytes': len(data), 'SHA256': digest(data)} for name, data in sorted(files.items())]
    files['manifesto.json'] = json_bytes(manifest)
    with zipfile.ZipFile(output / 'Acquisizione_tecnica.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in files.items():
            archive.writestr(name, data)
    create_report(work, output)
    verify_package(output, work)


def verify_package(output, work=None, expected_manifest_sha256=None):
    require({p.name for p in output.iterdir()} == ARTIFACTS, 'Il pacchetto deve contenere esattamente cinque file.')
    if expected_manifest_sha256:
        require(digest((output / 'SHA256.csv').read_bytes()).lower() == expected_manifest_sha256.lower(), 'Manifesto diverso dall’impronta di riferimento.')
    entries = list(csv.DictReader((output / 'SHA256.csv').open(encoding='utf-8-sig', newline='')))
    require({e['File'] for e in entries} == ARTIFACTS - {'SHA256.csv'} and len(entries) == 4, 'Manifesto incompleto o duplicato.')
    for entry in entries:
        path = output / entry['File']
        require(path.stat().st_size == int(entry['Bytes']) and digest(path.read_bytes()) == entry['SHA256'], 'Impronta del pacchetto non conforme.')
    with zipfile.ZipFile(output / 'Acquisizione_tecnica.zip') as archive:
        require(archive.testzip() is None, 'Archivio tecnico danneggiato.')
        inner = json.loads(archive.read('manifesto.json'))
        require(set(archive.namelist()) == {item['File'] for item in inner} | {'manifesto.json'}, 'Manifesto interno incompleto.')
        for entry in inner:
            data = archive.read(entry['File'])
            require(len(data) == entry['Bytes'] and digest(data) == entry['SHA256'], 'Impronta interna non conforme.')
        summary = json.loads(archive.read('riepilogo.json').decode('utf-8-sig'))
        require(json.loads(archive.read('verifiche.json'))['MessageCount'] == summary['MessageCount'], 'Conteggio del verbale tecnico non conforme.')
    with fitz.open(output / 'Verbale_acquisizione.pdf') as pdf:
        text = unicodedata.normalize('NFKC', '\n'.join(p.get_text() for p in pdf))
        require(str(summary['MessageCount']) in text and pdf.embfile_count() >= 1, 'Verbale non conforme.')
    receipt_hash = None
    if work and (work / 'consegna-finale.json').exists():
        receipt_path = work / 'consegna-finale.json'
        receipt = read_json(receipt_path)
        require(receipt['Status'] == 'Verified' and {e['File'] for e in receipt['Files']} == ARTIFACTS and len(receipt['Files']) == 5, 'Registro finale di consegna incompleto.')
        for entry in receipt['Files']:
            require(digest((output / entry['File']).read_bytes()).upper() == entry['SHA256'], 'Riscontro di consegna non conforme al pacchetto.')
        receipt_hash = digest(receipt_path.read_bytes())
    result = {'Status': 'Verified', 'VerifiedAtUtc': datetime.now(timezone.utc).isoformat(), 'MessageCount': summary['MessageCount'], 'ManifestSHA256': digest((output / 'SHA256.csv').read_bytes()), 'FinalDeliveryReceiptSHA256': receipt_hash}
    if work:
        (work / 'verifica-finale.json').write_bytes(json_bytes(result))
    print('Pacchetto verificato: ' + str(summary['MessageCount']) + ' messaggi; manifesti e archivio conformi.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('dependencies', 'package', 'report', 'verify'))
    parser.add_argument('--work', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--expected-manifest-sha256')
    args = parser.parse_args()
    if args.command == 'dependencies':
        require(tuple(map(int, fitz.VersionBind.split('.')[:3])) >= (1, 25, 2), 'PyMuPDF 1.25.2 o successivo richiesto.')
        return
    require(args.output is not None, 'Indicare --output.')
    if args.command != 'verify':
        require(args.work is not None, 'Indicare --work.')
    if args.command == 'package':
        package_acquisition(args.work, args.output)
    elif args.command == 'report':
        create_report(args.work, args.output)
    else:
        verify_package(args.output, args.work, args.expected_manifest_sha256)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('Verifica non riuscita: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
