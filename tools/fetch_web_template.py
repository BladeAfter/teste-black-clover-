"""Fetch only needed official export templates using HTTP ranges (no full archive)."""
import io, json, pathlib, urllib.request, zipfile
VERSION = '4.7.2'
UA = {'User-Agent': 'Clover-local-export'}
metadata_url = f'https://api.github.com/repos/godotengine/godot/releases/tags/{VERSION}-stable'
with urllib.request.urlopen(urllib.request.Request(metadata_url, headers=UA), timeout=30) as r:
    metadata = json.load(r)
asset = next(a for a in metadata['assets'] if a['name'] == f'Godot_v{VERSION}-stable_export_templates.tpz')
class RemoteZip(io.RawIOBase):
    def __init__(self, url, size):
        self.url, self.length, self.offset = url, size, 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.offset
    def seek(self, offset, whence=0):
        self.offset = offset if whence == 0 else self.offset + offset if whence == 1 else self.length + offset
        return self.offset
    def read(self, size=-1):
        if size < 0: size = self.length - self.offset
        size = min(size, self.length - self.offset)
        if size <= 0: return b''
        if size > 150 * 1024 * 1024: raise RuntimeError('Refusing unexpectedly large template segment')
        headers = dict(UA, Range=f'bytes={self.offset}-{self.offset+size-1}')
        with urllib.request.urlopen(urllib.request.Request(self.url, headers=headers), timeout=60) as r:
            if r.status != 206: raise RuntimeError('Server does not support selective template download')
            data = r.read(size)
        if len(data) != size: raise RuntimeError('Truncated template segment')
        self.offset += len(data)
        return data
remote = RemoteZip(asset['browser_download_url'], asset['size'])
with zipfile.ZipFile(remote) as archive:
    entries = [n for n in archive.namelist() if 'web_' in n or n.endswith(('version.txt','android_debug.apk','android_release.apk'))]
    print('AVAILABLE', entries, flush=True)
    target = pathlib.Path.home() / 'AppData/Roaming/Godot/export_templates' / f'{VERSION}.stable'
    target.mkdir(parents=True, exist_ok=True)
    for name in entries:
        if name.endswith(('web_nothreads_release.zip', 'web_nothreads_debug.zip', 'version.txt','android_debug.apk','android_release.apk')):
            destination = target / pathlib.PurePosixPath(name).name
            if destination.exists():
                print('EXISTS', destination.name, flush=True)
                continue
            info = archive.getinfo(name)
            print('FETCH', name, info.compress_size, flush=True)
            destination.write_bytes(archive.read(name))
            print('SAVED', destination, flush=True)
