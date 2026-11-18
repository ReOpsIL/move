import csv, sys, random
random.seed(7)
bands=[(600,1100),(1100,1400),(1400,1700),(1700,2000),(2000,2300),(2300,3200)]
per=1500
buckets={b:[] for b in bands}
with open(sys.argv[1]) as f:
    r=csv.DictReader(f)
    for row in r:
        try:
            rt=int(row['Rating']); rd=int(row['RatingDeviation']); pop=int(row['Popularity']); n=int(row['NbPlays'])
        except: continue
        if rd>85 or pop<85 or n<300: continue
        mv=row['Moves'].split()
        if len(mv)<2 or len(mv)>10: continue
        for b in bands:
            if b[0]<=rt<b[1]: buckets[b].append(row); break
out=open(sys.argv[2],'w')
for b in bands:
    rows=buckets[b]; random.shuffle(rows); rows=rows[:per]
    print(b,len(buckets[b]),len(rows), file=sys.stderr)
    for row in rows:
        themes=row['Themes'].replace(',',' ')
        out.write(f"{row['PuzzleId']},{row['FEN']},{row['Moves']},{row['Rating']},{themes}\n")
