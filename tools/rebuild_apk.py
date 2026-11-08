import zipfile, sys
src, arsc, dst = sys.argv[1:4]
with zipfile.ZipFile(src) as zi, zipfile.ZipFile(dst, 'w') as zo:
    for info in zi.infolist():
        if info.filename.startswith('META-INF/'): continue
        data = open(arsc,'rb').read() if info.filename == 'resources.arsc' else zi.read(info.filename)
        ni = zipfile.ZipInfo(info.filename, date_time=info.date_time)
        ni.compress_type = zipfile.ZIP_STORED if info.filename == 'resources.arsc' else info.compress_type
        ni.external_attr = info.external_attr
        zo.writestr(ni, data)
