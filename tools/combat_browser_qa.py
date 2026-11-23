import subprocess
from playwright.sync_api import sync_playwright

server = subprocess.Popen(['node', 'tools/serve-phaser.cjs'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='C:/Program Files/Google/Chrome/Application/chrome.exe', headless=True)
        page = browser.new_page()
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto('http://127.0.0.1:4173/phaser/')
        page.wait_for_function('window.__idleGame?.ready', timeout=60000)
        result = page.evaluate('''async () => {
            const g = window.__idleGame;
            g.setPaused(true);
            const m = await import('/phaser/combat-sprite-fx.mjs');
            const effects = [];
            for (const element of ['antimagia','vento','agua','escuridao','fogo','eletricidade']) {
                for (const special of [false,true]) effects.push(m.playCombatFX(g.scene, {
                    element, special, from:{x:200,y:500}, to:{x:700,y:500}
                }));
            }
            const visible = effects.every(s => s.active && s.texture.key === 'clover-generated-combat');
            await new Promise(resolve => setTimeout(resolve,1500));
            return {visible, removed:effects.every(s => !s.active)};
        }''')
        assert result['visible'] and result['removed'], result
        assert not errors, errors
        browser.close()
        print('COMBAT_BROWSER_QA: PASS (12 animations, automatic cleanup, no JavaScript errors)')
finally:
    server.terminate()
