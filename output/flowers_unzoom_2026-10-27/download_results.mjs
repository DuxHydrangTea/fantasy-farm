import fs from 'node:fs';
import path from 'node:path';
const root = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/, '$1'));
const jobs = JSON.parse(fs.readFileSync(path.join(root, 'pixellab-jobs.json'), 'utf8'));
fs.mkdirSync(path.join(root, 'unzoom'), {recursive: true});
let cursor = 0;
async function worker() {
  while(cursor < jobs.length) {
    const job = jobs[cursor++];
    if (!job.result?.includes('status: completed')) throw new Error(`Incomplete ${job.index}`);
    const filename = path.join(root, 'unzoom', `flower_${String(job.index).padStart(2, '0')}.png`);
    if (fs.existsSync(filename)) continue;
    const url = job.result.match(/download:\s*(https:\/\/\S+)/)?.[1];
    if (!url) throw new Error(`Missing URL ${job.index}`);
    const r = await fetch(url);
    if (!r.ok) throw new Error(`Download ${job.index}: ${r.status}`);
    fs.writeFileSync(filename, Buffer.from(await r.arrayBuffer()));
  }
}
await Promise.all([worker(), worker(), worker()]);
console.log('Downloaded all 30 actual PixelLab Unzoom outputs.');
