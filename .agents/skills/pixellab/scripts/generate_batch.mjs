import fs from 'node:fs';
import path from 'node:path';
import https from 'node:https';
import { callPixelLabTool } from './pixellab.mjs';

function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        return downloadFile(res.headers.location, dest).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`Failed to download: status ${res.statusCode}`));
      }
      const file = fs.createWriteStream(dest);
      res.pipe(file);
      file.on('finish', () => {
        file.close(() => resolve(dest));
      });
    }).on('error', reject);
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function generateAndSave(name, params, outputPath) {
  console.log(`\n=== Starting generation for: ${name} ===`);
  console.log(`Params:`, JSON.stringify(params, null, 2));

  const startRes = await callPixelLabTool('create_image_pixen', params);
  console.log(`Create response:`, JSON.stringify(startRes, null, 2));

  // Extract job_id
  let jobId = null;
  if (startRes.result?.content) {
    for (const c of startRes.result.content) {
      try {
        const parsed = JSON.parse(c.text);
        if (parsed.job_id || parsed.id) {
          jobId = parsed.job_id || parsed.id;
          break;
        }
      } catch (e) {
        const match = c.text.match(/job_id["':\s]+([a-zA-Z0-9_\-]+)/);
        if (match) jobId = match[1];
      }
    }
  }

  if (!jobId) {
    throw new Error(`Could not find job_id in response: ${JSON.stringify(startRes)}`);
  }

  console.log(`Polling job_id: ${jobId}...`);
  let attempts = 0;
  let finalUrl = null;

  while (attempts < 30) {
    await sleep(4000);
    attempts++;
    const pollRes = await callPixelLabTool('get_image', { job_id: jobId });
    const content = pollRes.result?.content?.[0]?.text;
    if (!content) {
      console.log(`Attempt ${attempts}: No content yet`);
      continue;
    }

    try {
      const data = JSON.parse(content);
      console.log(`Attempt ${attempts} status: ${data.status}`);
      if (data.status === 'completed' || data.status === 'success') {
        finalUrl = data.image?.url || data.url || data.result?.url;
        break;
      }
      if (data.status === 'failed' || data.status === 'error') {
        throw new Error(`Job failed: ${JSON.stringify(data)}`);
      }
    } catch (e) {
      if (e.message.startsWith('Job failed')) throw e;
      // Plain text response?
      if (content.includes('completed') || content.includes('http')) {
        const urlMatch = content.match(/https?:\/\/[^\s"'<>]+/);
        if (urlMatch) {
          finalUrl = urlMatch[0];
          break;
        }
      }
      console.log(`Attempt ${attempts} raw text: ${content.slice(0, 100)}...`);
    }
  }

  if (!finalUrl) {
    throw new Error(`Timed out waiting for job ${jobId}`);
  }

  console.log(`Downloading image from: ${finalUrl}`);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  await downloadFile(finalUrl, outputPath);
  console.log(`Successfully saved to: ${outputPath}`);
  return outputPath;
}
