import https from 'node:https';
import fs from 'node:fs';
import path from 'node:path';

const API_KEY = process.env.PIXELLAB_API_KEY || '5d9a189d-bb17-4040-9c81-e547c10c5001';
const MCP_URL = 'https://api.pixellab.ai/mcp';

export async function callPixelLabTool(toolName, args = {}) {
  const payload = JSON.stringify({
    jsonrpc: '2.0',
    id: Date.now(),
    method: 'tools/call',
    params: {
      name: toolName,
      arguments: args
    }
  });

  return new Promise((resolve, reject) => {
    const req = https.request(
      MCP_URL,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${API_KEY}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/event-stream'
        }
      },
      (res) => {
        let rawData = '';
        res.on('data', (chunk) => {
          rawData += chunk;
        });
        res.on('end', () => {
          try {
            const lines = rawData.split(/\r?\n/);
            const dataLine = lines.find((l) => l.startsWith('data: '));
            if (!dataLine) {
              return resolve({ raw: rawData });
            }
            const json = JSON.parse(dataLine.slice(6));
            resolve(json);
          } catch (e) {
            reject(new Error(`Failed to parse response: ${e.message}\nRaw: ${rawData}`));
          }
        });
      }
    );

    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

// CLI usage: node pixellab.mjs <toolName> [jsonArgs or @jsonFile]
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/, '$1'))) {
  const [,, tool, ...rest] = process.argv;
  if (!tool) {
    console.log('Usage: node pixellab.mjs <toolName> [jsonArgs or @jsonFile]');
    process.exit(1);
  }
  let argsStr = rest.join(' ').trim();
  let args = {};
  if (argsStr.startsWith('@')) {
    args = JSON.parse(fs.readFileSync(argsStr.slice(1), 'utf8'));
  } else if (argsStr) {
    args = JSON.parse(argsStr);
  }
  callPixelLabTool(tool, args)
    .then((res) => {
      console.log(JSON.stringify(res, null, 2));
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
