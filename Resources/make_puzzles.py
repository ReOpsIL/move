"""Build Resources/puzzles.csv from the Lichess puzzle dump (CC0).

    curl -O https://database.lichess.org/lichess_db_puzzle.csv.zst
    zstd -d lichess_db_puzzle.csv.zst
    python3 make_puzzles.py lichess_db_puzzle.csv puzzles.csv [per_level] [existing.csv]

Keeps well-rated, popular, short puzzles and samples `per_level` (default 10000)
from each rating band. Puzzles already in `existing.csv` are kept first, so ids
the app has marked as seen stay valid.
"""
import csv, sys, random

random.seed(7)
bands = [(600, 1100), (1100, 1400), (1400, 1700), (1700, 2000), (2000, 2300), (2300, 3200)]
per = int(sys.argv[3]) if len(sys.argv) > 3 else 10000

keep = set()
if len(sys.argv) > 4:
    with open(sys.argv[4]) as f:
        keep = {line.split(',', 1)[0] for line in f if line.strip()}

buckets = {b: ([], []) for b in bands}  # (kept, candidates)
with open(sys.argv[1]) as f:
    for row in csv.DictReader(f):
        try:
            rt = int(row['Rating']); rd = int(row['RatingDeviation'])
            pop = int(row['Popularity']); n = int(row['NbPlays'])
        except (ValueError, KeyError):
            continue
        mv = row['Moves'].split()
        if len(mv) < 2 or len(mv) > 10:
            continue
        old = row['PuzzleId'] in keep
        if not old and (rd > 85 or pop < 85 or n < 300):
            continue
        for b in bands:
            if b[0] <= rt < b[1]:
                buckets[b][0 if old else 1].append(row)
                break

with open(sys.argv[2], 'w') as out:
    for b in bands:
        kept, cand = buckets[b]
        random.shuffle(cand)
        rows = kept + cand[:max(0, per - len(kept))]
        print(b, f"kept={len(kept)} available={len(cand)} total={len(rows)}", file=sys.stderr)
        for row in rows:
            themes = row['Themes'].replace(',', ' ')
            out.write(f"{row['PuzzleId']},{row['FEN']},{row['Moves']},{row['Rating']},{themes}\n")
