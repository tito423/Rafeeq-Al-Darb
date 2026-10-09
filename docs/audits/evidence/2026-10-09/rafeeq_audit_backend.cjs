const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = 'E:/My Projects/Rafiq-Al-Darb';
const ts = require(path.join(root,'sync_backend/node_modules/typescript'));
const source = fs.readFileSync(path.join(root,'sync_backend/src/index.ts'),'utf8');
const compiled = ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
const calls=[];
const env={DB:{prepare(sql){return {bind(...args){this.args=args;return this},async run(){calls.push({sql,args:this.args})},async all(){return {results:[]}}}},async batch(statements){calls.push(...statements)}}};
// Test doubles isolate D1 and Google; this makes NO live writes and does not test real Google authentication.
const context={exports:{},Request,Response,URL,Date,Set,console,fetch:async()=>Response.json({iss:'https://accounts.google.com',aud:'227986327850-ha6gea87kueaeg2a3582ecpu3s0nbnh1.apps.googleusercontent.com',exp:String(Math.floor(Date.now()/1000)+3600),sub:'audit-isolated-account'})};
vm.runInNewContext(compiled,context);
const worker=context.exports.default;
const output=[];
async function post(route,body,headers={}){return worker.fetch(new Request('https://audit.invalid'+route,{method:'POST',headers:{'content-type':'application/json',...headers},body:JSON.stringify(body)}),env,{})}
(async()=>{
 let res=await post('/review',{reviewer:'isolated-test',notes:[{id:'entry',note:'integrity probe'}]});
 output.push({scenario:'unauthenticated review write',status:res.status,result:await res.json(),statements:calls.length});
 calls.length=0;
 const counters=Array.from({length:1001},(_,i)=>({key:'tasbeeh_total',event_id:String(i),increment_value:1}));
 res=await post('/sync',{counters},{Authorization:'Bearer isolated-google-double'});
 output.push({scenario:'1001 queued counters',status:res.status,result:await res.json(),received:counters.length,persisted:calls.length,discarded:counters.length-calls.length});
 calls.length=0;
 const notes=[{id:'large-body',note:'x'.repeat(2*1024*1024)}];
 res=await post('/review',{reviewer:'isolated-test',notes});
 output.push({scenario:'review body over 2 MiB',status:res.status,bytes:Buffer.byteLength(JSON.stringify({reviewer:'isolated-test',notes})),result:await res.json()});
 calls.length=0;
 const updates=[{key:'quran_last_page',value:'1',updated_at:'far-future-text'}];
 res=await post('/sync',{updates},{Authorization:'Bearer isolated-google-double'});
 output.push({scenario:'non-numeric state timestamp',status:res.status,passed_to_D1:calls[0]?.args?.[3],result:await res.json()});
 const doc={scope:'Local execution of actual transpiled Worker with explicit Google and D1 test doubles; no live authenticated request or production write.',results:output};
 fs.writeFileSync(path.join(root,'docs/audits/evidence/2026-10-09/backend-reproduction.json'),JSON.stringify(doc,null,2));
 console.log(JSON.stringify(doc,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
