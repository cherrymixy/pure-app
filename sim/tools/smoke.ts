/**
 * window.pure 계약 스모크 테스트 (STEP 2 검증용, 번들 제외).
 *
 * 설치된 Chrome 을 헤드리스로 띄워 dev 서버를 열고, 부록 B 계약을 하나씩 호출해
 * 실제로 동작하는지 확인한다. WebGL·WASM 이 실제로 도는 환경이어야 의미가 있으므로
 * jsdom 이 아니라 진짜 Chrome 을 쓴다.
 *
 *   npm run dev          (다른 터미널)
 *   npx tsx tools/smoke.ts
 */

import puppeteer from 'puppeteer-core';

const BASE = process.env.SIM_URL ?? 'http://127.0.0.1:5173/';
// 포즈 프로브는 ?probe=1 로 연다 (운영 빌드에서도 검사할 수 있게).
const URL = BASE + (BASE.includes('?') ? '&' : '?') + 'probe=1';
const CHROME =
  process.env.CHROME_PATH ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

interface Case {
  name: string;
  run: string;
  /** 결과를 판정한다. 반환값이 문자열이면 실패 사유. */
  check?: (value: unknown) => string | null;
}

const ok = () => null;

const CASES: Case[] = [
  {
    name: 'ready 가 resolve 된다',
    run: `await window.pure.ready; return 'ok';`,
    check: (v) => (v === 'ok' ? null : `ready 실패: ${String(v)}`),
  },
  {
    name: 'WebGL 2.0 컨텍스트가 살아 있다',
    run: `
      const c = document.getElementById('stage');
      const gl = c.getContext('webgl2') || c.getContext('webgl');
      if (!gl) return 'NO_CONTEXT';
      return { version: gl.getParameter(gl.VERSION), err: gl.getError() };
    `,
    check: (v) => {
      const r = v as { version?: string; err?: number };
      if (!r?.version) return `WebGL 컨텍스트 없음 (${String(v)})`;
      if (r.err !== 0) return `glGetError ${r.err}`;
      return null;
    },
  },
  {
    name: '동작 15종 이름이 맞다',
    run: `return window.pure.behaviors();`,
    check: (v) => {
      const expected = 'idle doze sleep wake nod shake look_around curious happy sad alert greet sweep focus home'.split(' ');
      const got = v as string[];
      if (!Array.isArray(got)) return '배열 아님';
      const missing = expected.filter((b) => !got.includes(b));
      const extra = got.filter((b) => !expected.includes(b));
      if (missing.length || extra.length) return `누락 ${missing} / 추가 ${extra}`;
      return null;
    },
  },
  {
    name: '얼굴 7종 이름이 맞다',
    run: `return window.pure.faces().slice().sort();`,
    check: (v) => {
      const expected = ['heart', 'neutral', 'sad', 'sleepy', 'smile', 'surprise', 'tilt'];
      const got = v as string[];
      return JSON.stringify(got) === JSON.stringify(expected) ? null : `받은 값: ${JSON.stringify(got)}`;
    },
  },
  {
    name: 'limits 가 계약 관절 이름으로 온다',
    run: `return window.pure.limits();`,
    check: (v) => {
      const got = v as Record<string, [number, number]>;
      const want: Record<string, [number, number]> = {
        base_yaw: [-150, 150],
        shoulder_pitch: [-35, 55],
        elbow_pitch: [-120, 33],
        head_pan: [-160, 160],
        head_tilt: [-33, 42],
      };
      for (const [k, [lo, hi]] of Object.entries(want)) {
        const g = got?.[k];
        if (!g) return `${k} 없음`;
        if (Math.abs(g[0] - lo) > 0.5 || Math.abs(g[1] - hi) > 0.5) {
          return `${k} = [${g[0].toFixed(1)}, ${g[1].toFixed(1)}], 기대 [${lo}, ${hi}]`;
        }
      }
      return null;
    },
  },
  {
    name: "playBehavior('happy') 로 로봇이 움직인다",
    run: `
      const before = window.__poseProbe();
      window.pure.playBehavior('happy');
      await new Promise(r => setTimeout(r, 1400));
      const after = window.__poseProbe();
      return Math.max(...Object.keys(before).map(k => Math.abs(after[k] - before[k])));
    `,
    check: (v) => ((v as number) > 1 ? null : `최대 관절 변화가 ${v}° — 안 움직였다`),
  },
  {
    name: "playRecipe 가 끝나면 ended 이벤트가 온다",
    run: `
      const id = window.pure.playRecipe({ steps: [{ behavior: 'greet', speed: 1.4, repeat: 1 }] });
      const got = await window.__waitEvent('ended', 12000);
      return got && got.id === id ? 'ok' : JSON.stringify(got);
    `,
    check: (v) => (v === 'ok' ? null : `ended 미수신/불일치: ${String(v)}`),
  },
  {
    name: 'capture() 가 비어 있지 않은 PNG 를 준다',
    run: `
      const url = window.pure.capture();
      if (!url.startsWith('data:image/png')) return 'NOT_PNG:' + url.slice(0, 40);
      {
        // 완전히 투명하거나 단색이면 preserveDrawingBuffer 문제다.
        const img = new Image(); img.src = url;
        await img.decode();
        const cv = document.createElement('canvas'); cv.width = img.width; cv.height = img.height;
        const ctx = cv.getContext('2d'); ctx.drawImage(img, 0, 0);
        const d = ctx.getImageData(0, 0, cv.width, cv.height).data;
        let distinct = new Set(); let opaque = 0;
        for (let i = 0; i < d.length; i += 4 * 97) {
          if (d[i+3] > 0) opaque++;
          distinct.add(\`\${d[i]},\${d[i+1]},\${d[i+2]}\`);
        }
        return { bytes: url.length, w: img.width, h: img.height, opaque, distinct: distinct.size };
      }
    `,
    check: (v) => {
      const r = v as { opaque?: number; distinct?: number; w?: number };
      if (typeof v === 'string') return v;
      if (!r?.opaque) return '전부 투명 — preserveDrawingBuffer 문제';
      if ((r.distinct ?? 0) < 3) return `색이 ${r.distinct}종뿐 — 아무것도 안 그려졌다`;
      return null;
    },
  },
  {
    name: "setFace('heart') 가 받아들여진다",
    run: `window.pure.setFace('heart'); return 'ok';`,
    check: ok,
  },
  {
    name: '알 수 없는 동작은 조용히 넘어가지 않고 던진다',
    run: `
      try { window.pure.playBehavior('moonwalk'); return 'NO_THROW'; }
      catch (e) { return e.message.includes('moonwalk') ? 'ok' : 'WRONG_MSG:' + e.message; }
    `,
    check: (v) => (v === 'ok' ? null : String(v)),
  },
  {
    name: '클립의 알 수 없는 관절 이름은 던진다 (조용한 0 트랙 아님)',
    run: `
      try {
        window.pure.playClip({ format: 'lelamp.clip/1', duration: 2,
          tracks: { wrist_pitch: [{ t: 0, value: 0 }] } });
        return 'NO_THROW';
      } catch (e) { return e.message.includes('wrist_pitch') ? 'ok' : 'WRONG_MSG:' + e.message; }
    `,
    check: (v) => (v === 'ok' ? null : String(v)),
  },
  {
    name: '계약 관절 이름으로 준 클립은 실제로 그 축을 움직인다',
    run: `
      window.pure.stop();
      await new Promise(r => setTimeout(r, 900));
      const before = window.__poseProbe();
      window.pure.playClip({ format: 'lelamp.clip/1', duration: 2.0, tracks: {
        head_pan: [{ t: 0, value: 0 }, { t: 1.0, value: 70 }, { t: 2.0, value: 70 }]
      }});
      await new Promise(r => setTimeout(r, 1600));
      const after = window.__poseProbe();
      return { head_pan: after.head_pan - before.head_pan, base_yaw: after.base_yaw - before.base_yaw };
    `,
    check: (v) => {
      const r = v as { head_pan?: number };
      if (!r || typeof r.head_pan !== 'number') return `측정 실패: ${JSON.stringify(v)}`;
      return Math.abs(r.head_pan) > 20 ? null : `head_pan 이 ${r.head_pan.toFixed(1)}° 만 움직였다 — 이름 변환 실패 의심`;
    },
  },
  {
    name: 'stop() 하면 얼어붙지 않고 대기 모션으로 돌아간다',
    run: `
      window.pure.stop();
      await new Promise(r => setTimeout(r, 1500));
      const a = window.__poseProbe();
      await new Promise(r => setTimeout(r, 1200));
      const b = window.__poseProbe();
      return Math.max(...Object.keys(a).map(k => Math.abs(b[k] - a[k])));
    `,
    check: (v) => ((v as number) > 0.05 ? null : `stop 뒤 움직임 ${v}° — 멈춰 있다`),
  },
];

const PROBE = `
  window.__events = [];
  window.addEventListener('message', (e) => { if (e.data && e.data.type) window.__events.push(e.data); });
  window.__waitEvent = (type, ms) => new Promise((resolve) => {
    const found = window.__events.find((e) => e.type === type);
    if (found) return resolve(found);
    const t0 = Date.now();
    const iv = setInterval(() => {
      const f = window.__events.find((e) => e.type === type);
      if (f) { clearInterval(iv); resolve(f); }
      else if (Date.now() - t0 > ms) { clearInterval(iv); resolve(null); }
    }, 50);
  });
  window.__poseProbe = () => {
    // 캔버스는 읽을 수 없으니 액추에이터 명령값을 직접 본다 (계약 이름으로 환산).
    const p = window.__simPose ? window.__simPose() : null;
    return p ?? {};
  };
`;

async function main(): Promise<void> {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: true,
    args: ['--enable-unsafe-swiftshader', '--use-gl=angle', '--no-sandbox', '--window-size=900,900'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 900, height: 900 });

  const consoleErrors: string[] = [];
  page.on('console', (m) => {
    if (m.type() === 'error') consoleErrors.push(m.text());
  });
  page.on('pageerror', (e) => consoleErrors.push(`pageerror: ${e.message}`));
  page.on('requestfailed', (r) => consoleErrors.push(`요청 실패: ${r.url()}`));
  page.on('response', (r) => {
    if (r.status() >= 400) consoleErrors.push(`HTTP ${r.status()}: ${r.url()}`);
  });

  await page.goto(URL, { waitUntil: 'load', timeout: 60_000 });
  await page.evaluate(PROBE);
  await page.evaluate(`window.pure.ready`).catch(() => {});

  let failed = 0;
  for (const c of CASES) {
    let value: unknown;
    let thrown: string | null = null;
    try {
      value = await page.evaluate(`(async () => { ${c.run} })()`);
    } catch (e) {
      thrown = e instanceof Error ? e.message : String(e);
    }
    const reason = thrown ?? c.check?.(value) ?? null;
    if (reason) {
      failed += 1;
      console.log(`  ✗ ${c.name}\n      ${reason}`);
    } else {
      const shown =
        typeof value === 'object' && value !== null ? JSON.stringify(value) : String(value);
      console.log(`  ✓ ${c.name}${shown && shown !== 'ok' ? `  → ${shown.slice(0, 90)}` : ''}`);
    }
  }

  if (consoleErrors.length) {
    console.log('\n  콘솔 에러:');
    for (const e of [...new Set(consoleErrors)].slice(0, 10)) console.log(`    ${e}`);
  }

  await browser.close();
  console.log(`\n${failed === 0 ? '전부 통과' : `${failed}건 실패`} (${CASES.length}건 중)`);
  process.exit(failed === 0 ? 0 : 1);
}

void main();
