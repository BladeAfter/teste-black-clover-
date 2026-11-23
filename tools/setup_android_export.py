"""Install official portable JDK and minimal Android SDK for non-Gradle APK export."""
import concurrent.futures, hashlib, json, os, pathlib, shutil, urllib.request, xml.etree.ElementTree as ET, zipfile
base = pathlib.Path(os.environ['LOCALAPPDATA'])
cache = base / 'CloverBuildTools/downloads'
cache.mkdir(parents=True, exist_ok=True)
request = urllib.request.Request('https://api.github.com/repos/adoptium/temurin17-binaries/releases/latest', headers={'User-Agent':'Clover-local-export'})
with urllib.request.urlopen(request, timeout=30) as r:
    release = json.load(r)
binary = next(a for a in release['assets'] if a['name'].startswith('OpenJDK17U-jdk_x64_windows_hotspot_') and a['name'].endswith('.zip'))
checksum_asset = next(a for a in release['assets'] if a['name'] == binary['name'] + '.sha256.txt')
with urllib.request.urlopen(checksum_asset['browser_download_url'], timeout=30) as r:
    checksum = r.read().decode().split()[0]
jdk = {'link':binary['browser_download_url'], 'checksum':checksum}
with urllib.request.urlopen('https://dl.google.com/android/repository/repository2-3.xml', timeout=30) as r:
    repository = ET.fromstring(r.read())
def android_package(path):
    for package in repository.findall('remotePackage'):
        if package.attrib['path'] != path: continue
        for archive in package.findall('./archives/archive'):
            if archive.findtext('host-os') == 'windows':
                complete = archive.find('complete')
                return 'https://dl.google.com/android/repository/' + complete.findtext('url'), complete.findtext('checksum')
    raise RuntimeError('Official package unavailable: ' + path)
def fetch(url, name, checksum, algorithm):
    destination = cache / name
    if not destination.exists():
        print('DOWNLOAD', name, flush=True)
        with urllib.request.urlopen(url, timeout=90) as response, destination.open('wb') as output:
            shutil.copyfileobj(response, output, 1024 * 1024)
    digest = hashlib.new(algorithm)
    with destination.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''): digest.update(chunk)
    if digest.hexdigest().lower() != checksum.lower(): raise RuntimeError('Checksum mismatch: ' + name)
    return destination
def extract(archive_path, target, strip_first=False):
    target.mkdir(parents=True, exist_ok=True)
    resolved = target.resolve()
    with zipfile.ZipFile(archive_path) as z:
        for entry in z.infolist():
            parts = pathlib.PurePosixPath(entry.filename).parts
            relative = pathlib.Path(*parts[1:]) if strip_first else pathlib.Path(*parts)
            if not relative.parts: continue
            output = (target / relative).resolve()
            if not output.is_relative_to(resolved): raise RuntimeError('Unsafe archive path')
            if entry.is_dir(): output.mkdir(parents=True, exist_ok=True)
            else:
                output.parent.mkdir(parents=True, exist_ok=True)
                with z.open(entry) as source, output.open('wb') as destination: shutil.copyfileobj(source, destination)
sdk = base / 'Android/Sdk'
jdk_root = base / 'CloverBuildTools/jdk17'
items = [(jdk['link'], 'jdk17.zip', jdk['checksum'], 'sha256', jdk_root, True)]
for package, name, target, strip in [('build-tools;35.0.1','build-tools-35.0.1.zip',sdk/'build-tools/35.0.1',True),('platform-tools','platform-tools.zip',sdk,False)]:
    url, checksum = android_package(package)
    items.append((url,name,checksum,'sha1',target,strip))
def install(item):
    url,name,checksum,algorithm,target,strip = item
    fetched = fetch(url,name,checksum,algorithm)
    extract(fetched,target,strip)
    print('INSTALLED', target, flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool: list(pool.map(install,items))
settings = pathlib.Path(os.environ['APPDATA'])/'Godot/editor_settings-4.7.tres'
text = settings.read_text(encoding='utf-8')
lines = text.splitlines()
for i,line in enumerate(lines):
    if line.startswith('export/android/java_sdk_path = '): lines[i] = 'export/android/java_sdk_path = ' + json.dumps(jdk_root.as_posix())
    if line.startswith('export/android/android_sdk_path = '): lines[i] = 'export/android/android_sdk_path = ' + json.dumps(sdk.as_posix())
settings.write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('ANDROID_TOOLCHAIN_READY', flush=True)
