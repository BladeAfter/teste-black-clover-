"""Browser smoke test: actual exported Godot game and a mocked Telegram client API."""
import functools, http.server, json, pathlib, threading
from playwright.sync_api import sync_playwright
root = pathlib.Path(__file__).resolve().parents[1]
class QuietServer(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
handler = functools.partial(QuietServer, directory=str(root/'build/telegram'))
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
url = 'http://127.0.0.1:%d/' % server.server_port
mock = '''window.__tgCalls=[];window.__tgHandlers={};window.Telegram={WebApp:{isFullscreen:false,
isVersionAtLeast:()=>true,ready:()=>{},expand:()=>{},setHeaderColor:()=>{},setBackgroundColor:()=>{},disableVerticalSwipes:()=>{},onEvent:(name,callback)=>{window.__tgHandlers[name]=callback},
requestFullscreen(){window.__tgCalls.push('fullscreen')},lockOrientation(){window.__tgCalls.push(innerWidth>innerHeight?'lock-landscape':'lock-portrait')},unlockOrientation(){window.__tgCalls.push('unlock')},
BackButton:{show(){window.__tgCalls.push('back-show')},hide(){window.__tgCalls.push('back-hide')},onClick(f){window.__telegramBack=f}}}};'''
errors=[]
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='C:/Program Files/Google/Chrome/Application/chrome.exe', headless=True, args=['--enable-unsafe-swiftshader','--use-angle=swiftshader'])
        context = browser.new_context(viewport={'width':360,'height':640}, is_mobile=True, has_touch=True, device_scale_factor=1)
        context.route('https://telegram.org/js/telegram-web-app.js', lambda route: route.fulfill(content_type='application/javascript',body=mock))
        page = context.new_page()
        def tap_design(x,y,layer='content'):
            m=page.evaluate('CloverPlatform.layout')
            x += m['content_x']
            y += m['design_height']-1280 if layer=='navigation' else m['content_y']
            vx=m['x']+(-y if m['rotated'] else x)*m['scale']
            vy=m['y']+(x if m['rotated'] else y)*m['scale']
            a,b,c,d,tx,ty=m['final']
            page.touchscreen.tap(a*vx+c*vy+tx,b*vx+d*vy+ty)
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('console', lambda msg: errors.append(msg.text) if msg.type=='error' and ('SCRIPT ERROR' in msg.text or 'Failed to load' in msg.text) else None)
        page.goto(url)
        page.wait_for_selector('#loading',state='detached',timeout=60000)
        page.wait_for_timeout(1200)
        assert page.evaluate('CloverPlatform.landscape') is False
        page.screenshot(path=str(root/'artifacts/telegram-portrait-home.png'))
        page.touchscreen.tap(80,30)
        page.wait_for_timeout(350)
        page.screenshot(path=str(root/'artifacts/telegram-player-profile.png'))
        page.touchscreen.tap(108,387)
        page.touchscreen.tap(180,471)
        page.wait_for_timeout(250)
        page.touchscreen.tap(180,447)
        page.wait_for_function('CloverPlatform.landscape===true',timeout=10000)
        page.wait_for_timeout(800)
        page.screenshot(path=str(root/'artifacts/telegram-rotated-campaign.png'))
        # Native Godot transforms also map touch input to the rotated back button.
        page.touchscreen.tap(336,50)
        page.wait_for_function('CloverPlatform.landscape===false',timeout=10000)
        page.set_viewport_size({'width':640,'height':360})
        page.wait_for_timeout(600)
        page.touchscreen.tap(320,251)
        page.wait_for_function('CloverPlatform.landscape===true',timeout=10000)
        page.wait_for_timeout(600)
        page.screenshot(path=str(root/'artifacts/telegram-landscape-campaign.png'))
        page.evaluate('window.__telegramBack()')
        page.wait_for_function('CloverPlatform.landscape===false',timeout=10000)
        # Modern Android 20:9 portrait/landscape: full background, edge-anchored
        # navigation, real battle controls and repeated orientation changes.
        for width,height in [(412,915),(915,412),(393,852),(852,393)]:
            page.set_viewport_size({'width':width,'height':height})
            page.wait_for_timeout(600)
            tap_design(360,893)
            page.wait_for_function('CloverPlatform.landscape===true',timeout=10000)
            page.wait_for_timeout(600)
            tap_design(1045,649)
            page.wait_for_timeout(400)
            page.screenshot(path=str(root/('artifacts/telegram-mobile-%dx%d.png' % (width,height))))
            tap_design(1145,677)
            page.wait_for_function('CloverPlatform.landscape===false',timeout=10000)
            page.wait_for_timeout(300)
        page.set_viewport_size({'width':412,'height':915})
        page.wait_for_timeout(500)
        tap_design(360,1226,layer='navigation')
        page.wait_for_function("CloverPlatform.layout.page===String.fromCharCode(70,111,114,109,97,231,227,111) && CloverPlatform.landscape===true",timeout=10000)
        page.evaluate('window.__telegramBack()')
        page.wait_for_timeout(300)
        assert page.evaluate("__tgCalls.includes('fullscreen') && __tgCalls.includes('back-show') && __tgCalls.includes('back-hide')")
        page.evaluate("Telegram.WebApp.contentSafeAreaInset={left:18,top:22,right:30,bottom:12};__tgHandlers.contentSafeAreaChanged()")
        page.wait_for_timeout(300)
        assert page.evaluate('CloverPlatform.layout.x+0.1 >= CloverPlatform.layout.width*18/innerWidth && CloverPlatform.layout.y+0.1 >= CloverPlatform.layout.height*22/innerHeight'), page.evaluate('CloverPlatform.layout')
        # Real mobile touches reach the final page and load the fourth hero atlas.
        tap_design(107,1226,layer='navigation')
        page.wait_for_function("CloverPlatform.layout.page===String.fromCharCode(72,101,114,243,105,115)",timeout=10000)
        for _ in range(17):
            tap_design(610,635)
            page.wait_for_timeout(180)
        tap_design(360,375)
        page.wait_for_timeout(600)
        page.screenshot(path=str(root/'artifacts/telegram-roster-last-page.png'))
        assert not errors, errors
        (root/'artifacts/telegram-browser-qa.json').write_text(json.dumps({'status':'PASS','touch_rotation':True,'landscape_view':True,'telegram_back':True,'safe_area':True,'errors':errors},indent=2),encoding='utf-8')
        print('TELEGRAM_BROWSER_QA: PASS',flush=True)
        browser.close()
finally: server.shutdown()
