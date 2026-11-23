"""Render and check the offline gallery with its real transparent PNGs."""
from pathlib import Path
from playwright.sync_api import sync_playwright

root=Path(__file__).resolve().parents[1]
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='C:/Program Files/Google/Chrome/Application/chrome.exe',headless=True)
 page=browser.new_page(viewport={'width':1440,'height':1000},device_scale_factor=1)
 page.goto((root/'assets/dragon-ball/index.html').as_uri())
 page.wait_for_function('document.images.length===20 && [...document.images].every(i=>i.complete && i.naturalWidth>0)',timeout=15000)
 assert page.locator('.card').count()==20
 assert page.locator('a.download').count()==20
 page.screenshot(path=str(root/'artifacts/dragon-ball-gallery.png'),full_page=True)
 page.set_viewport_size({'width':412,'height':915})
 assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
 page.screenshot(path=str(root/'artifacts/dragon-ball-gallery-mobile.png'))
 browser.close()
 print('DRAGON_BALL_GALLERY_QA: PASS - 20 images, 20 downloads, desktop and mobile')
