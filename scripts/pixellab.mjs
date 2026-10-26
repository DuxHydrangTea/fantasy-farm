import https from 'node:https';
import fs from 'node:fs';
import path from 'node:path';

// Read project credentials for every request so a running helper cannot retain an old key.
function configuredApiKey() {
  if (process.env.PIXELLAB_API_KEY) return process.env.PIXELLAB_API_KEY;
  const config = JSON.parse(fs.readFileSync(new URL('../.mcp.json', import.meta.url), 'utf8'));
  const server = (config.mcpServers || config.mcp_servers || {}).pixellab;
  const authorization = server?.headers?.Authorization || server?.headers?.authorization || server?.env?.AUTH_HEADER;
  if (!authorization || !/^Bearer\s+\S+$/i.test(authorization)) {
    throw new Error('PixelLab API key missing from project MCP configuration.');
  }
  return authorization.replace(/^Bearer\s+/i, '');
}

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
          'Authorization': `Bearer ${configuredApiKey()}`,
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
