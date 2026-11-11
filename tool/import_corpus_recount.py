"""Validate an existing recount ledger and export read-only app statistics.

No PDF text, machine paths or dictionary definitions are exported to the app.
Run: python tool/import_corpus_recount.py <recount-folder>
"""
import argparse
import csv
import hashlib
import io
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORPORA = ('textbook', 'abstract')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def normalize(term):
    return ' '.join(term.lower().split())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    source = args.source.resolve()
    manifest = json.loads((source / 'manifest.json').read_text(encoding='utf-8'))
    recount = json.loads((source / 'recount.json').read_text(encoding='utf-8'))
    documents = manifest['documents']
    counts = Counter(d['corpus'] for d in documents)
    assert counts == {'textbook': 22, 'abstract': 639}, counts
    docs = {d['docid']: d for d in documents}
    assert len(docs) == len(documents)
    assert len({d['doi'] for d in documents if d['corpus'] == 'abstract'}) == 639
    for d in documents:
        assert digest(Path(d['path'])) == d['sha256'], d['docid']
    for path, expected in recount['source_hashes'].items():
        assert digest(Path(path)) == expected, Path(path).name
    results = recount['results']
    terms = {normalize(r['term_en']): r for r in results}
    ids = {r['term_id']: r for r in results}
    assert len(results) == len(terms) == len(ids) == 834
    with (ROOT / 'assets/vocabulary/recall_core_v1.csv').open(encoding='utf-8-sig') as f:
        vocabulary = list(csv.DictReader(f))
    assert set(terms) == {normalize(r['term_en']) for r in vocabulary}

    tf = Counter()
    df = defaultdict(set)
    seen = set()
    with (source / 'occurrences.jsonl').open(encoding='utf-8') as f:
        for line in f:
            e = json.loads(line)
            assert e['term_id'] in ids and e['docid'] in docs
            assert e['corpus'] == docs[e['docid']]['corpus']
            assert normalize(e['term']) == normalize(ids[e['term_id']]['term_en'])
            unique = (e['term_id'], e['docid'], e['page'], e['start'], e['end'])
            assert unique not in seen, unique
            seen.add(unique)
            if e['status'] in ('accepted', 'pending'):
                key = (e['term_id'], e['corpus'], e['status'])
                tf[key] += 1
                df[key].add(e['docid'])
    for r in results:
        for corpus in CORPORA:
            for status in ('accepted', 'pending'):
                key = (r['term_id'], corpus, status)
                assert r[f'{corpus}_{status}_tf'] == tf[key], key
                assert r[f'{corpus}_{status}_df'] == len(df[key]), key
                assert 0 <= len(df[key]) <= min(tf[key], counts[corpus])

    output = io.StringIO(newline='')
    writer = csv.writer(output, lineterminator='\n')
    writer.writerow(['term_en', 'textbook_tf', 'textbook_df', 'abstract_tf', 'abstract_df'])
    pending = {}
    categories = Counter()
    for v in vocabulary:
        r = terms[normalize(v['term_en'])]
        values = [r[f'{c}_accepted_{metric}'] for c in CORPORA for metric in ('tf', 'df')]
        writer.writerow([v['term_en'], *values])
        categories['both' if values[1] and values[3] else 'textbookOnly' if values[1]
                   else 'abstractOnly' if values[3] else 'unobserved'] += 1
        p = [r[f'{c}_pending_{metric}'] for c in CORPORA for metric in ('tf', 'df')]
        if any(p):
            pending[normalize(v['term_en'])] = p
    assert categories == {'both': 225, 'textbookOnly': 326, 'abstractOnly': 37, 'unobserved': 246}
    data = output.getvalue().encode('utf-8')
    metadata = {
        'schema_version': 1, 'dataset_id': 'recall-recount-20261111',
        'basis': 'provisional_accepted', 'date': '2026-11-11',
        'textbook_documents': 22, 'abstract_documents': 639,
        'csv_sha256': hashlib.sha256(data).hexdigest(),
        'pending': pending,
        'source_hashes': {name: digest(source / name) for name in
                          ('recount.json', 'manifest.json', 'occurrences.jsonl', 'term_rules.json')},
        'audit': {'occurrences': len(seen), 'verified_documents': len(docs),
                  'matched_terms': len(terms), 'categories': dict(categories)},
    }
    target = ROOT / 'assets/corpus'
    # Do not modify either app asset until every source check has passed.
    (target / 'corpus_stats.csv').write_bytes(data)
    (target / 'corpus_metadata.json').write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(metadata['audit']))


if __name__ == '__main__':
    main()
