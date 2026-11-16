import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()


def rep(a, b, count=1):
    global s
    if s.count(a) < 1:
        raise SystemExit('NICHT GEFUNDEN: ' + a[:100].replace('\n', ' | '))
    s = s.replace(a, b, count)


rep('''def build_vehicle(out: str | None, log=print) -> None:''', '''def write_wav_import_keep(path: str, loop) -> None:
    """ml.write_wav_import() that keeps the [remap]/[deps] head of an existing .import file (uid and import path).
    modern_lib opens the file for writing before it reads the old head, which empties it: after every new run the
    sound could not be loaded until Godot had imported it again, under a new uid."""
    imp = path + ".import"
    head = ""
    if os.path.exists(imp):
        with open(imp, encoding="utf-8") as fh:
            head = fh.read().split("[params]")[0].strip("\\n")
    ml.write_wav_import(path, loop)
    if head:
        with open(imp, encoding="utf-8") as fh:
            params = fh.read().split("[params]", 1)[1]
        with open(imp, "w", encoding="utf-8") as fh:
            fh.write(head + "\\n\\n[params]" + params)


def build_vehicle(out: str | None, log=print) -> None:''')
rep('''            if repo:
                ml.write_wav_import(man.file(name), loop)''', '''            if repo:
                write_wav_import_keep(man.file(name), loop)''')
# balance: K-weighted and plain power together
rep('''    y = steady(cycles, period)
    pl, pr = kpow(y[:, 0]), kpow(y[:, 1])
    if pl <= 0.0 or pr <= 0.0:
        return 0.0
    g = (pl / pr) ** 0.25          # half of the difference to each side''', '''    y = steady(cycles, period)
    pl, pr = kpow(y[:, 0]), kpow(y[:, 1])
    ql, qr = float(np.mean(y[:, 0] ** 2)), float(np.mean(y[:, 1] ** 2))
    if min(pl, pr, ql, qr) <= 0.0:
        return 0.0
    # the mean of the K-weighted and the plain difference: where the two channels differ in spectrum (two exhaust
    # systems of unequal length) neither the loudness nor the level ends up more than half of their gap apart
    g = (math.sqrt((pl / pr) * (ql / qr))) ** 0.25          # half of the difference to each side''')
rep('''def balance_channels(cycles: list, period: int) -> float:
    """Levels the two channels of a bank against each other (K-weighted power over all variants); returns the
    correction applied to the right channel in dB."""''', '''def balance_channels(cycles: list, period: int) -> float:
    """Levels the two channels of a bank against each other (power over all variants, K-weighted and plain);
    returns the correction applied to the right channel in dB."""''')
open(p, 'w', encoding='utf-8').write(s)
print('ok')
