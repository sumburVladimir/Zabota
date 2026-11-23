# -*- coding: utf-8 -*-
"""
Сверка услуг из брифа (docx/txt) с группами процедур клиники.

Что делает:
  1. Разбирает бриф на секции по кодам сценариев (IW3, PW4, PW5.1, ...).
  2. Достаёт из каждой секции услуги вида "A22.01.004Лазерная ... / зона"
     (код МКБ отрезается).
  3. Ищет каждую услугу в procedures.Descr (точное совпадение после нормализации,
     затем fuzzy) и показывает, в каких группах procedurex она лежит.
  4. Сравнивает с составом указанной группы: чего не хватает, что лишнее.

Использование:
  python tools/brief_group_match.py \
      --brief "C:/path/brief.docx" \
      --exp expdata.xls --procedures procedures.xls \
      --check IW3=19 --check PW4=28 --check PW4=27 \
      --out report.txt

  --check КОД=GROUP_ID  можно указывать несколько раз (для баз с группами процедур).
  --find-only           только сопоставить услуги брифа со справочником и выдать
                        proc_id — для баз, где услуги перечисляются в сегменте.
  --list                только разобрать бриф и показать услуги по секциям.
"""
import argparse
import difflib
import html
import re
import sys
import zipfile
from pathlib import Path

import pandas as pd

MARK = re.compile(r'^(?:IW|PW|SW|CW|FW|MW|DW|NW|TW)\d+(?:\.\d+)?$')
CODE_RE = re.compile(r'[АA]\s?\d{2}\.\d{2}\.\d{3}(?:\.\d{3})?')
SPLIT_RE = re.compile(r'(?=[АA]\d{2}\.\d{2}\.\d{3})')


def docx_to_text(path: Path) -> str:
    """Достаёт текст из docx без python-docx (docx = zip с document.xml)."""
    with zipfile.ZipFile(path) as z:
        xml = z.read('word/document.xml').decode('utf-8')
    xml = re.sub(r'</w:p>', '\n', xml)
    xml = re.sub(r'</w:tc>', '\t', xml)
    xml = re.sub(r'</w:tr>', '\n', xml)
    text = html.unescape(re.sub(r'<[^>]+>', '', xml))
    return text


def load_brief(path: Path) -> list[str]:
    if path.suffix.lower() == '.docx':
        return docx_to_text(path).split('\n')
    return path.read_text(encoding='utf-8').split('\n')


def section_bounds(lines: list[str]) -> dict[str, tuple[int, int]]:
    marks = [(i, l.strip()) for i, l in enumerate(lines) if MARK.match(l.strip())]
    out = {}
    for idx, (i, code) in enumerate(marks):
        end = marks[idx + 1][0] if idx + 1 < len(marks) else len(lines)
        out[code] = (i, end)
    return out


def norm(s: str) -> str:
    s = str(s).lower().replace('ё', 'е').replace('\u00a0', ' ')
    s = re.sub(r'[«»"„“”\'`]', '', s)
    s = re.sub(r'[^\wа-я0-9]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def services(lines: list[str], bounds: dict, code: str) -> list[str]:
    if code not in bounds:
        return []
    a, b = bounds[code]
    out = []
    for raw in lines[a:b]:
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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--brief', required=True, help='бриф .docx или .txt')
    ap.add_argument('--exp', help='выгрузка procedurex + procgroups (xls/csv)')
    ap.add_argument('--procedures', help='выгрузка procedures (xls/csv)')
    ap.add_argument('--check', action='append', default=[],
                    help='КОД=GROUP_ID, можно несколько раз')
    ap.add_argument('--find-only', action='store_true',
                    help='только сопоставить услуги со справочником и выдать proc_id')
    ap.add_argument('--list', action='store_true', help='показать услуги по секциям')
    ap.add_argument('--out', help='куда писать отчёт (по умолчанию stdout)')
    args = ap.parse_args()

    lines = load_brief(Path(args.brief))
    bounds = section_bounds(lines)
    if not bounds:
        print('Не найдено ни одной секции вида IW3/PW4 в брифе', file=sys.stderr)
        return 2

    if args.list:
        for code in bounds:
            svc = services(lines, bounds, code)
            if svc:
                print(f'{code}: {len(svc)} услуг')
        return 0

    if not args.procedures:
        print('Нужен --procedures (справочник услуг)', file=sys.stderr)
        return 2
    if args.check and not args.exp:
        print('Для --check нужен --exp (выгрузка procedurex/procgroups)', file=sys.stderr)
        return 2

    proc = pd.read_excel(args.procedures) if args.procedures.lower().endswith(('.xls', '.xlsx')) \
        else pd.read_csv(args.procedures)
    proc = proc.rename(columns={'Procedure_id': 'pid', 'Descr': 'descr'})
    pmap = dict(zip(proc.pid, proc.descr))
    allnorm = {}
    for pid, d in pmap.items():
        if pd.notna(d):
            allnorm.setdefault(norm(d), pid)

    exp = None
    gmembers, gmeta = {}, {}
    if args.exp:
        exp = pd.read_excel(args.exp) if args.exp.lower().endswith(('.xls', '.xlsx')) \
            else pd.read_csv(args.exp)
        gmembers = exp.groupby('group_id')['proc_id'].apply(lambda s: sorted(int(x) for x in s)).to_dict()
        for r in exp.itertuples():
            gmeta.setdefault(int(r.group_id), (str(getattr(r, 'code1', '')).strip(),
                                               str(getattr(r, 'name', '')).strip()))

    out = []
    if args.find_only:
        for code in bounds:
            svc = services(lines, bounds, code)
            if not svc:
                continue
            out.append('=' * 90)
            out.append(f'{code}: {len(svc)} услуг')
            for s in svc:
                n = norm(s)
                pid = allnorm.get(n)
                how = ''
                if pid is None:
                    cand = difflib.get_close_matches(n, list(allnorm), n=1, cutoff=0.97)
                    if cand:
                        pid = allnorm[cand[0]]
                        how = f'  (похожее: {pmap[pid]})'
                if pid is None:
                    out.append(f'  ??   {s}')
                else:
                    out.append(f'  {pid:<6} {pmap[pid]}{how}')
        text = '\n'.join(out)
        if args.out:
            Path(args.out).write_text(text, encoding='utf-8')
            print(f'отчёт: {args.out}')
        else:
            print(text)
        return 0

    for spec in args.check:
        if '=' not in spec:
            print(f'--check ожидает КОД=GROUP_ID, получено: {spec}', file=sys.stderr)
            continue
        code, gid = spec.split('=', 1)
        gid = int(gid)
        svc = services(lines, bounds, code.strip())
        mem = set(gmembers.get(gid, []))
        matched, missing = [], []
        for s in svc:
            n = norm(s)
            pid = allnorm.get(n)
            how = 'точное'
            if pid is None:
                cand = difflib.get_close_matches(n, list(allnorm), n=1, cutoff=0.97)
                if cand:
                    pid = allnorm[cand[0]]
                    how = f'похожее: {pmap[pid]}'
            (matched if pid in mem else missing).append((s, pid, how))

        out.append('=' * 100)
        out.append(f'{code} (группа {gid} «{gmeta.get(gid, ("?", ""))[0]}»): '
                   f'услуг в брифе {len(svc)}, совпало {len(matched)}, нет в группе {len(missing)}')
        for s, pid, how in missing:
            where = sorted({g for g, ps in gmembers.items() if pid in ps}) if pid else []
            groups = ', '.join(f'{gmeta.get(g, (g,))[0]}({g})' for g in where) or 'нет ни в одной группе'
            out.append(f'  НЕТ В ГРУППЕ: {s}')
            out.append(f'     proc_id={pid}, лежит в группах: {groups}' + (f'  [{how}]' if how != 'точное' else ''))
        extra = [p for p in mem if p not in {m[1] for m in matched}]
        if extra:
            out.append(f'  лишних в группе: {len(extra)}')
            for p in sorted(extra):
                out.append(f'     + {p}: {pmap.get(p)}')
        out.append('')

    text = '\n'.join(out)
    if args.out:
        Path(args.out).write_text(text, encoding='utf-8')
        print(f'отчёт: {args.out}')
    else:
        print(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
