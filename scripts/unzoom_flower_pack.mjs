import fs from 'node:fs';
import {callPixelLabTool} from './pixellab.mjs';
const output='docs/flower_sprites_2026-10-26';
const rows=JSON.parse(fs.readFileSync(`${output}/inputs.json`,'utf8'));
fs.mkdirSync(`${output}/jobs`,{recursive:true});
fs.mkdirSync(`${output}/unzoom`,{recursive:true});
function texts(reply){return (reply.result?.content||reply.content||[]).filter(x=>x.type==='text').map(x=>x.text).join('\n');}
let cursor=0;
async function worker(){
 while(cursor<rows.length){
  const row=rows[cursor++];const stem=row.kind==='pot'?'soil_pot':`flower_${String(row.index).padStart(2,'0')}`;
  const metadata=`${output}/jobs/${stem}.json`;
  let job=fs.existsSync(metadata)?JSON.parse(fs.readFileSync(metadata,'utf8')):null;
  if(job?.downloaded){console.log(`kept ${stem}`);continue;}
  if(!job?.job_id){
   let text='',match=null;
   for(let retry=0;retry<4;retry++){
    const reply=await callPixelLabTool('unzoom_image',{image_base64:fs.readFileSync(row.input).toString('base64'),quantize:64});
    text=texts(reply);match=text.match(/job_id:\s*([\w-]+)/);
    if(match)break;
    if(!/temporarily unavailable|rate limit|long queues/i.test(text)||retry===3)throw new Error(`${stem}: ${text}`);
    console.log(`Waiting for free queue: ${stem}, retry ${retry+1}`);
    await new Promise(resolve=>setTimeout(resolve,10000*(retry+1)));
   }
   job={...row,job_id:match[1],submit:text};fs.writeFileSync(metadata,JSON.stringify(job,null,2));
   console.log(`submitted ${stem}`);
  }
  for(let attempt=0;attempt<12;attempt++){
   const reply=await callPixelLabTool('get_image',{job_id:job.job_id});const text=texts(reply);
   const url=text.match(/download:\s*(https:\/\/\S+)/)?.[1] || reply.result?.structuredContent?.download_url;
   if(url){
    const image=await fetch(url);if(!image.ok)throw new Error(`${stem} download ${image.status}`);
    const dest=`${output}/unzoom/${stem}.png`;fs.writeFileSync(dest,Buffer.from(await image.arrayBuffer()));
    job={...job,result:text,downloaded:dest};fs.writeFileSync(metadata,JSON.stringify(job,null,2));console.log(`completed ${stem}`);break;
   }
   if(/status:\s*(failed|error)/.test(text)||reply.result?.isError)throw new Error(`${stem}: ${text}`);
   if(attempt===11)throw new Error(`${stem} not finished; rerun to resume existing job`);
   await new Promise(resolve=>setTimeout(resolve,1000));
  }
 }
}
await worker();
console.log('All 33 PixelLab jobs downloaded.');
