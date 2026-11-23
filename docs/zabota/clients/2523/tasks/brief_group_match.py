# -*- coding: utf-8 -*-
import re, json, pandas as pd, difflib

BRIEF = r'C:\Users\Владимир Капов\AppData\Local\Temp\opencode\brief.txt'
EXP   = r'C:\Users\Владимир Капов\Desktop\выгрузки\expdata.csv'
PROC  = r'C:\Users\Владимир Капов\Desktop\выгрузки\procedures.csv'

lines = open(BRIEF, encoding='utf-8').read().split('\n')
starts = {}
for i, l in enumerate(lines):
    s = l.strip()
    if re.fullmatch(r'IW\d+', s):
        starts[s] = i

def section(code):
    i = starts[code]
    nxt = min([v for v in starts.values() if v > i] + [len(lines)])
    return lines[i:nxt]

CODE_RE = re.compile(r'[АA]\s?\d{2}\.\d{2}\.\d{3}(?:\.\d{3})?')
SPLIT_RE = re.compile(r'(?=[АA]\d{2}\.\d{2}\.\d{3})')

def brief_services(code):
    out = []
    for raw in section(code):
        s = raw.strip().replace('\u00a0', ' ')
        if not s or not CODE_RE.search(s[:10]):
            continue
        for part in [p.strip() for p in SPLIT_RE.split(s) if p.strip()]:
            if CODE_RE.search(part[:10]):
                name = CODE_RE.sub('', part, count=1)
                name = re.sub(r'\*+', '', name)
                name = re.sub(r'\s+', ' ', name).strip(' -/')
                if len(name) > 3:
                    out.append(name)
    return out

def norm(s):
    s = str(s).lower().replace('ё', 'е').replace('\u00a0', ' ')
    s = re.sub(r'[«»"„“”\'`]', '', s)
    s = re.sub(r'[^\wа-я0-9]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()

exp = pd.read_csv(EXP)
proc = pd.read_csv(PROC).rename(columns={'Procedure_id': 'pid', 'Descr': 'descr'})
pmap = dict(zip(proc.pid, proc.descr))
allnorm = {norm(d): d for d in proc.descr if pd.notna(d)}
groups = {code: sorted(int(x) for x in g.group_id.unique()) for code, g in exp.groupby(exp.code1.str.strip())}

TARGET = ['IW2', 'IW3', 'IW6', 'IW7', 'IW9', 'IW11', 'IW12', 'IW13']
report = {}
for code in TARGET:
    svc = brief_services(code)
    gids = groups.get(code.strip(), [])
    rows = exp[exp.code1.str.strip() == code]
    base = [(int(r.proc_id), pmap.get(int(r.proc_id), '???')) for r in rows.itertuples()]
    bnorm = {norm(d): d for _, d in base}
    matched, missing = [], []
    for s in svc:
        ns = norm(s)
        if ns in bnorm:
            matched.append({'brief': s, 'base': bnorm[ns], 'how': 'exact'})
            continue
        best = max(bnorm.items(), key=lambda kv: difflib.SequenceMatcher(None, ns, kv[0]).ratio()) if bnorm else None
        r = difflib.SequenceMatcher(None, ns, best[0]).ratio() if best else 0
        if r >= 0.97:
            matched.append({'brief': s, 'base': best[1], 'how': f'fuzzy{r:.2f}'})
        else:
            in_cat = allnorm.get(ns)
            cand = difflib.get_close_matches(ns, list(allnorm), n=3, cutoff=0.7)
            cand_g = difflib.get_close_matches(ns, list(bnorm), n=2, cutoff=0.7)
            missing.append({'brief': s,
                            'в_группе_похожие': [(bnorm[c], round(difflib.SequenceMatcher(None, ns, c).ratio(), 2)) for c in cand_g],
                            'есть_в_справочнике_точно': in_cat is not None,
                            'в_справочнике_похожие': [(allnorm[c], round(difflib.SequenceMatcher(None, ns, c).ratio(), 2)) for c in cand]})
    used = {norm(m['base']) for m in matched}
    extra = [d for _, d in base if norm(d) not in used]
    report[code] = {'group': gids, 'brief_n': len(svc), 'base_n': len(base),
                    'matched': matched, 'missing': missing, 'extra': sorted(extra)}

json.dump(report, open(r'C:\Users\Владимир Капов\AppData\Local\Temp\opencode\report.json', 'w', encoding='utf-8'),
          ensure_ascii=False, indent=1)

out = []
for code, r in report.items():
    out.append(f"=== {code}  группа={r['group']}  в брифе={r['brief_n']}  в базе={r['base_n']}  "
               f"совпало={len(r['matched'])}  нет в группе={len(r['missing'])}  лишних в базе={len(r['extra'])}")
    fuzzy = [m for m in r['matched'] if m['how'] != 'exact']
    if fuzzy:
        out.append('  НЕТОЧНЫЕ СОВПАДЕНИЯ (проверить):')
        for m in fuzzy:
            out.append(f"   ~ {m['brief']}  <->  {m['base']}  [{m['how']}]")
    if r['missing']:
        out.append('  НЕТ В ГРУППЕ (по брифу):')
        for m in r['missing']:
            out.append(f"   - {m['brief']}")
            out.append(f"       в справочнике есть точно: {m['есть_в_справочнике_точно']}; похожие в справочнике: {m['в_справочнике_похожие']}")
            out.append(f"       похожие в группе: {m['в_группе_похожие']}")
    if r['extra']:
        out.append('  ЛИШНИЕ В ГРУППЕ (нет в брифе):')
        for e in r['extra']:
            out.append(f"   + {e}")
    out.append('')
open(r'C:\Users\Владимир Капов\AppData\Local\Temp\opencode\diff.txt', 'w', encoding='utf-8').write('\n'.join(out))
print('done')
