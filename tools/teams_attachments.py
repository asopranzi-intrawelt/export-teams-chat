"""Inventario e recupero dei file allegati a una conversazione gia' acquisita.

Legge il pacchetto consegnato, cioe' `Acquisizione_tecnica.zip`, e non una copia locale
dell'acquisizione: la fonte e' quindi la stessa che il verbale descrive, e il materiale
resta nella cartella indicata dal richiedente. Dall'archivio ricava il perimetro degli
allegati dichiarato nell'istruzione e, per i soli mesi di quel perimetro, nome, data,
mittente e collegamento di ogni allegato.

Con `--scarica` risolve ogni collegamento con l'endpoint `shares` di Graph e salva il file,
registrandone byte e impronta. I file recuperati vengono soltanto salvati e improntati: il
loro contenuto non viene aperto, convertito, estratto o riassunto. Il recupero richiede un
permesso applicativo sui file, cioe' Files.Read.All oppure Sites.Read.All; con i soli
permessi sulle chat l'inventario riesce e il recupero riporta un 403 per ogni allegato.
"""
import argparse
import base64
import csv
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from zoneinfo import ZoneInfo

ZONE = ZoneInfo('Europe/Rome')
GRAPH = 'https://graph.microsoft.com/v1.0'
LOGIN = 'https://login.microsoftonline.com/%s/oauth2/v2.0/token'
SAFE = re.compile(r'[^A-Za-z0-9._ -]+')
ARCHIVE = 'Acquisizione_tecnica.zip'


def token(config_path):
    config = json.loads(Path(config_path).read_text(encoding='utf-8-sig'))
    for field in ('TenantId', 'ClientId', 'ClientSecret'):
        if not str(config.get(field, '')).strip() or str(config[field]).startswith('<'):
            raise SystemExit('Compilare %s nel file di configurazione privato.' % field)
    body = urllib.parse.urlencode({
        'grant_type': 'client_credentials',
        'scope': 'https://graph.microsoft.com/.default',
        'client_id': config['ClientId'],
        'client_secret': config['ClientSecret'],
    }).encode('ascii')
    with urllib.request.urlopen(LOGIN % config['TenantId'], data=body, timeout=60) as response:
        return json.loads(response.read())['access_token']


def graph_get(url, bearer):
    # Il token non esce mai dall'endpoint Graph previsto.
    if not url.startswith(GRAPH + '/'):
        raise SystemExit('Endpoint Graph non valido: %s' % url)
    request = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + bearer})
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.loads(response.read())


def share_id(content_url):
    encoded = base64.urlsafe_b64encode(content_url.encode('utf-8')).decode('ascii')
    return 'u!' + encoded.rstrip('=')


def read_package(package):
    archive_path = Path(package) / ARCHIVE
    if not archive_path.is_file():
        raise SystemExit('Archivio tecnico non trovato: %s' % archive_path)
    with zipfile.ZipFile(archive_path) as archive:
        names = set(archive.namelist())
        if 'originale.json' not in names:
            raise SystemExit("L'archivio non contiene originale.json: pacchetto non conforme.")
        original = json.loads(archive.read('originale.json').decode('utf-8-sig'))
        instruction = json.loads(archive.read('istruzione.json').decode('utf-8-sig')) if 'istruzione.json' in names else {}
        summary = json.loads(archive.read('riepilogo.json').decode('utf-8-sig'))
    return original, instruction, summary


def scope_from(instruction, year, months):
    declared = instruction.get('AttachmentScope') or {}
    year = year or declared.get('Year')
    months = months or declared.get('Months')
    if not year or not months:
        raise SystemExit("Il perimetro degli allegati non e' dichiarato nell'istruzione: indicare --anno e --mesi.")
    return int(year), sorted(int(month) for month in months)


def collect(original, year, months):
    rows = []
    senza_collegamento = 0
    for chat in original:
        for message in chat.get('Messages') or []:
            created = datetime.fromisoformat(str(message['createdDateTime']).replace('Z', '+00:00'))
            # Il mese e' quello italiano, perche' il prospetto che indica i mesi mancanti ragiona cosi'.
            local = created.astimezone(ZONE)
            if local.year != year or local.month not in months:
                continue
            sender = ((message.get('from') or {}).get('user') or {}).get('displayName')
            for index, attachment in enumerate(message.get('attachments') or [], start=1):
                if not attachment.get('contentUrl'):
                    senza_collegamento += 1
                    continue
                rows.append({
                    'Mese': '%04d-%02d' % (local.year, local.month),
                    'DataLocale': local.strftime('%Y-%m-%d %H:%M:%S %z'),
                    'DataUtc': created.strftime('%Y-%m-%dT%H:%M:%SZ'),
                    'Mittente': sender or '(mittente non disponibile)',
                    'NomeFile': attachment.get('name') or '(senza nome)',
                    'TipoContenuto': attachment.get('contentType') or '',
                    'MessageId': message.get('id'),
                    'ChatId': chat.get('ChatId'),
                    'Indice': index,
                    'ContentUrl': attachment['contentUrl'],
                })
    rows.sort(key=lambda row: (row['DataUtc'], row['Indice']))
    return rows, senza_collegamento


def safe_name(row):
    base = SAFE.sub('_', row['NomeFile']).strip() or 'allegato'
    return '%s_%s_%s' % (row['DataLocale'][:10], row['Indice'], base)


def download(rows, destination, bearer):
    destination.mkdir(parents=True, exist_ok=True)
    for row in rows:
        row.update({'Esito': '', 'FileSalvato': '', 'Byte': '', 'SHA256': ''})
        try:
            item = graph_get('%s/shares/%s/driveItem' % (GRAPH, share_id(row['ContentUrl'])), bearer)
        except urllib.error.HTTPError as error:
            row['Esito'] = 'Graph %d %s' % (error.code, error.reason)
            continue
        link = item.get('@microsoft.graph.downloadUrl') or item.get('@content.downloadUrl')
        if not link:
            row['Esito'] = 'Nessun collegamento di scaricamento nella risposta'
            continue
        target = destination / safe_name(row)
        try:
            # Il collegamento restituito da Graph e' preautenticato: non vi si invia il token.
            with urllib.request.urlopen(link, timeout=300) as response:
                payload = response.read()
        except urllib.error.HTTPError as error:
            row['Esito'] = 'Scaricamento %d %s' % (error.code, error.reason)
            continue
        target.write_bytes(payload)
        row.update({'Esito': 'Scaricato', 'FileSalvato': target.name,
                    'Byte': len(payload), 'SHA256': sha256(payload).hexdigest()})
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--pacchetto', required=True, help='Cartella consegnata che contiene ' + ARCHIVE)
    parser.add_argument('--output', required=True, help='Cartella nuova per inventario e file recuperati')
    parser.add_argument('--anno', type=int, help='Anno, se l istruzione non dichiara il perimetro')
    parser.add_argument('--mesi', help='Mesi separati da virgola, se l istruzione non dichiara il perimetro')
    parser.add_argument('--config', help='Configurazione privata, necessaria solo con --scarica')
    parser.add_argument('--scarica', action='store_true', help='Tenta il recupero dei file, non solo l inventario')
    args = parser.parse_args()

    output = Path(args.output)
    if output.exists():
        raise SystemExit('Usare una cartella nuova: %s' % output)
    if args.scarica and not args.config:
        raise SystemExit('Indicare --config per il recupero dei file.')

    original, instruction, summary = read_package(args.pacchetto)
    months = [int(m) for m in args.mesi.split(',')] if args.mesi else None
    year, months = scope_from(instruction, args.anno, months)
    rows, senza_collegamento = collect(original, year, months)

    output.mkdir(parents=True)
    if args.scarica:
        download(rows, output / 'file', token(args.config))

    fields = ['Mese', 'DataLocale', 'DataUtc', 'Mittente', 'NomeFile', 'TipoContenuto',
              'MessageId', 'ChatId', 'Indice', 'ContentUrl']
    if args.scarica:
        fields += ['Esito', 'FileSalvato', 'Byte', 'SHA256']
    with (output / 'inventario-allegati.csv').open('w', encoding='utf-8-sig', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, '') for key in fields})

    per_mese = {'%04d-%02d' % (year, month): sum(1 for row in rows if row['Mese'] == '%04d-%02d' % (year, month))
                for month in months}
    record = {
        'GeneratoUtc': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'Pacchetto': str(Path(args.pacchetto)),
        'Partecipanti': [p.get('DirectoryName') for p in (summary.get('Participants') or [])],
        'MessaggiNelPacchetto': summary.get('MessageCount'),
        'Anno': year,
        'Mesi': months,
        'PerMese': per_mese,
        'MesiSenzaAllegati': [month for month in months if per_mese['%04d-%02d' % (year, month)] == 0],
        'Allegati': len(rows),
        'AllegatiSenzaCollegamento': senza_collegamento,
        'Perimetro': ('Allegati con collegamento nella risposta Graph, nei soli mesi dichiarati, '
                      'nella sola conversazione del pacchetto indicato.'),
        'Scaricati': sum(1 for row in rows if row.get('Esito') == 'Scaricato') if args.scarica else None,
        'Righe': rows,
    }
    (output / 'inventario-allegati.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    print('Pacchetto: %s' % Path(args.pacchetto).name)
    print('Allegati nei mesi richiesti: %d' % len(rows))
    for month in months:
        print('  %04d-%02d: %d' % (year, month, per_mese['%04d-%02d' % (year, month)]))
    if senza_collegamento:
        print('Allegati senza collegamento nella fonte, non inventariabili: %d' % senza_collegamento)
    if args.scarica:
        print('Scaricati: %d su %d' % (record['Scaricati'], len(rows)))
        for reason in sorted({row['Esito'] for row in rows if row.get('Esito') != 'Scaricato'}):
            print('  non recuperati: %s' % reason)
    print('Inventario: %s' % (output / 'inventario-allegati.csv'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
