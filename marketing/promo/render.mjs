// Rendert das Werbevideo Bild für Bild: Chromium (Playwright) zeigt index.html, Promo.seek(t) stellt
// den Zustand her, die PNGs gehen direkt an ffmpeg.
//
//   node render.mjs                    beide Sprachen → out/swipez-promo-de.mp4, -en.mp4
//   node render.mjs --lang en          nur Englisch
//   node render.mjs --frames 0,90,240  nur Einzelbilder (Bildnummern) → out/frame-<lang>-<nr>.png
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import ffmpegPath from 'ffmpeg-static';
import { chromium } from 'playwright';

const root = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(root, 'out');
mkdirSync(out, { recursive: true });

const args = process.argv.slice(2);
const option = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const langs = option('lang') && option('lang') !== 'all' ? [option('lang')] : ['de', 'en'];
const stills = option('frames')?.split(',').map(Number);

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
page.on('pageerror', (error) => {
  console.error('Fehler in der Seite:', error.message);
  process.exitCode = 1;
});

for (const lang of langs) {
  await page.goto(`${pathToFileURL(path.join(root, 'index.html'))}?render=1&lang=${lang}`);
  await page.evaluate(() => window.Promo.ready);
  const { duration, fps, photosFound, photosTotal } = await page.evaluate(() => ({
    duration: Promo.duration,
    fps: Promo.fps,
    photosFound: Promo.photosFound,
    photosTotal: Promo.photosTotal
  }));
  const total = Math.round(duration * fps);
  console.log(`[${lang}] ${total} Bilder, ${fps} fps, Fotos: ${photosFound} von ${photosTotal} Stellen belegt`);

  if (stills) {
    for (const frame of stills) {
      await page.evaluate((t) => Promo.seek(t), frame / fps);
      const file = path.join(out, `frame-${lang}-${String(frame).padStart(3, '0')}.png`);
      writeFileSync(file, await page.screenshot({ type: 'png' }));
      console.log('  ', path.relative(root, file));
    }
    continue;
  }

  const file = path.join(out, `swipez-promo-${lang}.mp4`);
  const ffmpeg = spawn(
    ffmpegPath,
    [
      '-y', '-loglevel', 'error',
      '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'png', '-i', '-',
      '-c:v', 'libx264', '-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p',
      '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709',
      '-movflags', '+faststart', '-r', String(fps), file
    ],
    { stdio: ['pipe', 'inherit', 'inherit'] }
  );
  const started = Date.now();
  for (let frame = 0; frame < total; frame++) {
    await page.evaluate((t) => Promo.seek(t), frame / fps);
    const png = await page.screenshot({ type: 'png' });
    if (!ffmpeg.stdin.write(png)) await once(ffmpeg.stdin, 'drain');
    if (frame % 60 === 0) process.stdout.write(`\r[${lang}] Bild ${frame}/${total}`);
  }
  ffmpeg.stdin.end();
  const [code] = await once(ffmpeg, 'close');
  if (code !== 0) throw new Error(`ffmpeg endete mit Code ${code}`);
  console.log(`\r[${lang}] fertig in ${Math.round((Date.now() - started) / 1000)} s → ${path.relative(root, file)}`);
}

await browser.close();
