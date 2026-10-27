import fs from 'node:fs';
import path from 'node:path';
const root = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/, '$1'));
const rows = JSON.parse(fs.readFileSync(path.join(root, 'inputs.json'), 'utf8'));
let cursor = 0;
async function worker() {
  while (cursor < rows.length) {
    const row = rows[cursor++];
    const body = new FormData();
    body.append('file', new Blob([fs.readFileSync(path.join(root, 'inputs', row.input))], {type: 'image/png'}), row.input);
    const response = await fetch(process.argv[2], {method: 'POST', body});
    if (!response.ok) throw new Error(`Upload ${row.index}: ${response.status}`);
    const result = await response.json();
    row.upload_ref = result.ref;
    if (!row.upload_ref) throw new Error(JSON.stringify(result));
  }
}
await Promise.all([worker(), worker(), worker()]);
fs.writeFileSync(path.join(root, 'uploads.json'), JSON.stringify(rows, null, 2));
console.log(JSON.stringify(rows.map(r => ({index: r.index, ref: r.upload_ref}))));
