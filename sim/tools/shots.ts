import puppeteer from 'puppeteer-core';
const OUT = process.env.OUT ?? '/tmp';
const b = await puppeteer.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: true,
  args: ['--enable-unsafe-swiftshader', '--use-gl=angle', '--no-sandbox'],
});
const page = await b.newPage();
await page.setViewport({ width: 640, height: 640, deviceScaleFactor: 2 });
await page.goto('http://127.0.0.1:5173/', { waitUntil: 'load', timeout: 60000 });
await page.evaluate('window.pure.ready');
const shots: [string, string][] = [
  ['idle', `window.pure.setIdle({behavior:'idle'})`],
  ['greet', `window.pure.playBehavior('greet')`],
  ['happy', `window.pure.playBehavior('happy')`],
  ['curious', `window.pure.playBehavior('curious')`],
];
for (const [name, code] of shots) {
  await page.evaluate(code);
  await new Promise((r) => setTimeout(r, 1800));
  await page.screenshot({ path: `${OUT}/sim-${name}.png` });
  console.log('찍음:', name);
}
await b.close();
