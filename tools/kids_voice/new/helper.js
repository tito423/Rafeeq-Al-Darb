window.__run=function(STYLE,TEXT){window.__res="RUNNING";(async()=>{
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const btn=re=>[...document.querySelectorAll('button')].find(b=>re.test(b.innerText.trim())||re.test(b.getAttribute('aria-label')||''));
function setTA(t,v){const s=Object.getOwnPropertyDescriptor((t instanceof HTMLInputElement?HTMLInputElement:HTMLTextAreaElement).prototype,'value').set;s.call(t,v);t.dispatchEvent(new Event('input',{bubbles:true}));t.dispatchEvent(new Event('change',{bubbles:true}));t.dispatchEvent(new Event('blur',{bubbles:true}));}
async function waitFor(f,ms=15000){let t=0;while(t<ms){const v=f();if(v)return v;await sleep(250);t+=250;}return null;}
if(!document.querySelector('[aria-label="Speech block"]')) (await waitFor(()=>[...document.querySelectorAll('span,div,p,h3')].find(e=>!e.childElementCount&&e.textContent.trim()==='Create new dialog')))?.click();
const b=await waitFor(()=>document.querySelector('[aria-label="Speech block"]')); if(!b) return 'NO BLOCK';
if(!b.querySelector('.voice-chip-label').textContent.includes('Sadaltager')){
  b.querySelector('.voice-chip-label').click();
  const inp=await waitFor(()=>document.querySelector('.cdk-overlay-container input')); setTA(inp,'Sadaltager'); inp.dispatchEvent(new Event('keyup',{bubbles:true}));
  const v=await waitFor(()=>[...document.querySelectorAll('.cdk-overlay-container button')].find(x=>x.innerText.trim().startsWith('Sadaltager')));
  if(!v) return 'NO VOICE'; v.click(); await sleep(600);
  [...document.querySelectorAll('.cdk-overlay-container button')].find(x=>x.innerText.trim()==='close')?.click(); await sleep(500);
}
if(!b.querySelector('.voice-chip-label').textContent.includes('Sadaltager')) return 'VOICE NOT SET';
b.querySelector('button[aria-label="Style"]').click();
setTA(await waitFor(()=>document.querySelector('textarea.daikon-custom-style-textarea')),STYLE); await sleep(300);
document.querySelector('.cdk-overlay-backdrop')?.click(); await sleep(400);
setTA(b.querySelector('textarea[aria-label="Speech block text"]'),TEXT); await sleep(300);
if(!b.querySelector('.chip-label').textContent.endsWith(STYLE.slice(-30))) return 'STYLE NOT SET';
const before=document.querySelector('audio')?.src||''; btn(/^Run/).click(); await sleep(3000);
let t=0; while(t<240){ if(![...document.querySelectorAll('button')].some(x=>x.innerText.includes('Stop'))) break; await sleep(1000); t++; }
const a=document.querySelector('audio')?.src||'';
if(!a.startsWith('data:audio')||a===before) return 'NO NEW AUDIO';
await sleep(1000); btn(/^Download$/).click(); await sleep(1500);
const tm=[...document.querySelectorAll('span,div')].filter(e=>!e.childElementCount&&/^\d+:\d\d$/.test(e.textContent.trim())).map(e=>e.textContent.trim());
return 'OK '+t+'s '+tm.join('/')+' b64len '+a.length;
})().then(r=>window.__res=r,e=>window.__res="ERR "+e);return "started";};"installed"
