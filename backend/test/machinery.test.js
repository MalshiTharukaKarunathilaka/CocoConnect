const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
process.env.DB_MODE='memory';process.env.PORT='5091';process.env.JWT_SECRET='machinery-test-secret';
let server;const base='http://localhost:5091/api/machinery';
async function call(method,path,token,body){const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:body?JSON.stringify(body):undefined});return {status:r.status,data:await r.json()};}
async function signup(phone,role){const body={name:role+' '+phone,phone,password:'secret123',role,location:'Kurunegala',latitude:7.4863,longitude:80.3647};
 if(role==='SERVICE_PROVIDER')body.service_provider={identity_number:'821940129V',category:'Machinery',machinery_type:'Tractor',district:'Kurunegala',address:'Machinery Yard',radius_km:5,terms_accepted:true};
 const r=await fetch('http://localhost:5091/api/auth/signup',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});assert.equal(r.status,201);return await r.json();}
async function ok(method,path,token,body,status=200){const r=await call(method,path,token,body);assert.equal(r.status,status,JSON.stringify(r.data));return r.data;}
before(async()=>{const http=require('http');const original=http.Server.prototype.listen;http.Server.prototype.listen=function(...args){server=this;return original.apply(this,args);};require('../server');http.Server.prototype.listen=original;await new Promise(resolve=>setTimeout(resolve,100));});
after(()=>server.close());
let provider,otherProvider,owner,stranger,buyer,m,rate,rate2,first,overlap;
const start='2030-04-20T02:30:00.000Z',end='2030-04-20T04:30:00.000Z';
const payload=()=>({estate_name:'Green Valley Estate',address:'Kurunegala',starts_at:start,ends_at:end,items:[{service_id:rate.id,quantity:8},{service_id:rate2.id,quantity:2}]});
test('machinery endpoints require login, correct roles and record ownership',async()=>{
 assert.equal((await call('GET','/provider/machines')).status,401);
 provider=await signup('0771000101','SERVICE_PROVIDER');otherProvider=await signup('0771000102','SERVICE_PROVIDER');owner=await signup('0771000103','ESTATE_OWNER');stranger=await signup('0771000104','ESTATE_OWNER');buyer=await signup('0771000105','BUYER');
 assert.equal((await call('POST','/provider/machines',owner.token,{name:'Not allowed',category:'Tractor'})).status,403);
 m=await ok('POST','/provider/machines',provider.token,{name:'Sunil Tractor',category:'Tractor'},201);
 assert.equal((await call('GET',`/provider/machines/${m.id}/calendar?month=2030-04`,otherProvider.token)).status,404);
 assert.equal((await call('GET','/machines',buyer.token)).status,403);
});
test('rates are validated, saved and visible in the owner machinery API',async()=>{
 rate=await ok('PUT',`/provider/machines/${m.id}/rates`,provider.token,{name:'Disc Ploughing',unit:'acre',rate:6800});
 rate2=await ok('PUT',`/provider/machines/${m.id}/rates`,provider.token,{name:'Slasher',unit:'acre',rate:5000});
 assert.equal((await call('PUT',`/provider/machines/${m.id}/rates`,otherProvider.token,{name:'Slasher',unit:'acre',rate:1})).status,404);
 assert.equal((await call('PUT',`/provider/machines/${m.id}/rates`,provider.token,{name:'Slasher',unit:'hour',rate:1})).status,400);
 const machines=await ok('GET','/machines',owner.token);assert.equal(machines.length,1);assert.equal(machines[0].services.length,2);
});
test('owner creates real multi-service requests; unrelated users cannot read them',async()=>{
 first=await ok('POST',`/machines/${m.id}/bookings`,owner.token,payload(),201);
 overlap=await ok('POST',`/machines/${m.id}/bookings`,owner.token,payload(),201);
 assert.equal(Number(first.proposed_total),64400);assert.equal(first.items.length,2);assert.equal(first.status,'PENDING');
 assert.equal((await call('GET',`/bookings/${first.id}`,stranger.token)).status,404);
 assert.equal((await call('GET',`/bookings/${first.id}`,otherProvider.token)).status,404);
 const calendar=await ok('GET',`/provider/machines/${m.id}/calendar?month=2030-04`,provider.token);assert.equal(calendar.bookings.length,2);
 await ok('PUT',`/provider/machines/${m.id}/rates`,provider.token,{name:'Disc Ploughing',unit:'acre',rate:7000});
 const saved=await ok('GET',`/bookings/${first.id}`,owner.token);assert.equal(Number(saved.items[0].rate),6800);
});
test('providers can only accept or decline; the owner changes the price and the request',async()=>{
 // a provider cannot send messages or counteroffers
 assert.equal((await call('POST',`/bookings/${first.id}/messages`,provider.token,{expected_version:first.version,message:'Can do it for less.',offer_total:60000})).status,403);
 assert.equal((await call('POST',`/bookings/${first.id}/messages`,provider.token,{expected_version:first.version,message:'Hello'})).status,403);
 // the owner offers a different price; stale versions are refused
 assert.equal((await call('POST',`/bookings/${first.id}/messages`,owner.token,{expected_version:99,message:'Stale response'})).status,409);
 first=await ok('POST',`/bookings/${first.id}/messages`,owner.token,{expected_version:first.version,message:'Can you do the whole job for this total?',offer_total:60000},201);
 assert.equal(first.messages.length,2);assert.equal(first.proposed_by,owner.user.id);assert.equal(Number(first.proposed_total),60000);assert.equal(first.offer_agreed,false);
 // every offer carries the service date, in Sri Lankan time
 assert.match(first.messages[1].message,/Service date: Sat, 20 Apr 2030 - 08:00 AM to 10:00 AM/);
 assert.match(first.messages[0].message,/Service date: Sat, 20 Apr 2030/);
 // the provider answers the owner's offer with accept; there is nothing to counter
 first=await ok('POST',`/bookings/${first.id}/accept`,provider.token,{expected_version:first.version});
 assert.equal(first.status,'CONFIRMED');assert.equal(Number(first.agreed_total),60000);assert.equal(first.messages.length,3);
 assert.match(first.messages[2].message,/Service date:/);

 // the owner changes the work, the price and the time of another request
 const extra=await ok('POST',`/machines/${m.id}/bookings`,owner.token,{...payload(),starts_at:'2030-04-22T02:30:00.000Z',ends_at:'2030-04-22T06:30:00.000Z'},201);
 assert.equal((await call('POST',`/bookings/${extra.id}/revise`,owner.token,{expected_version:extra.version})).status,400);
 assert.equal((await call('POST',`/bookings/${extra.id}/revise`,provider.token,{expected_version:extra.version,offer_total:1000})).status,403);
 assert.equal((await call('POST',`/bookings/${extra.id}/revise`,stranger.token,{expected_version:extra.version,offer_total:1000})).status,404);
 assert.equal((await call('POST',`/bookings/${extra.id}/revise`,owner.token,{expected_version:99,offer_total:1000})).status,409);
 const revised=await ok('POST',`/bookings/${extra.id}/revise`,owner.token,{expected_version:extra.version,items:[{service_id:rate.id,quantity:3},{service_id:rate2.id,quantity:1}],message:'Smaller job please.'});
 assert.equal(Number(revised.proposed_total),3*7000+1*5000);assert.equal(revised.items.length,2);assert.equal(revised.offer_agreed,false);assert.equal(revised.proposed_by,owner.user.id);
 assert.equal(revised.messages.at(-1).message.startsWith('Smaller job please.'),true);
 assert.match(revised.messages.at(-1).message,/Service date: .*22 Apr 2030/);
 const priced=await ok('POST',`/bookings/${extra.id}/revise`,owner.token,{expected_version:revised.version,offer_total:20000});
 assert.equal(Number(priced.proposed_total),20000);assert.equal(priced.items.length,2);
 // a time that clashes with the confirmed booking is refused; a free one is saved
 assert.equal((await call('POST',`/bookings/${extra.id}/revise`,owner.token,{expected_version:priced.version,starts_at:start,ends_at:end})).status,409);
 const moved=await ok('POST',`/bookings/${extra.id}/revise`,owner.token,{expected_version:priced.version,starts_at:'2030-04-23T02:30:00.000Z',ends_at:'2030-04-23T04:30:00.000Z'});
 assert.match(moved.messages.at(-1).message,/Service date: .*23 Apr 2030/);
 // the provider can only decline it now (a stale version is refused first)
 assert.equal((await call('POST',`/bookings/${extra.id}/decline`,provider.token,{expected_version:priced.version})).status,409);
 const done=await ok('POST',`/bookings/${extra.id}/decline`,provider.token,{expected_version:moved.version});assert.equal(done.status,'DECLINED');
 assert.equal((await call('POST',`/bookings/${extra.id}/revise`,owner.token,{expected_version:done.version,offer_total:1000})).status,409);
});
test('overlaps are rejected, adjacent intervals work, and decline never reserves the date',async()=>{
 assert.equal((await call('POST',`/bookings/${overlap.id}/accept`,provider.token,{expected_version:overlap.version})).status,409);
 overlap=await ok('POST',`/bookings/${overlap.id}/decline`,provider.token,{expected_version:overlap.version});assert.equal(overlap.status,'DECLINED');
 const adjacent=await ok('POST',`/machines/${m.id}/bookings`,owner.token,{...payload(),starts_at:end,ends_at:'2030-04-20T06:30:00.000Z'},201);
 const confirmed=await ok('POST',`/bookings/${adjacent.id}/accept`,provider.token,{expected_version:adjacent.version});assert.equal(confirmed.status,'CONFIRMED');
 assert.equal((await call('PUT',`/provider/machines/${m.id}/availability`,provider.token,{day:'2030-04-20',state:'MAINTENANCE'})).status,409);
});
test('maintenance persists, blocks requests, and can be reopened without changing other days',async()=>{
 await ok('PUT',`/provider/machines/${m.id}/availability`,provider.token,{day:'2030-04-21',state:'MAINTENANCE',note:'Engine service'});
 const maintenancePayload={...payload(),starts_at:'2030-04-21T02:30:00.000Z',ends_at:'2030-04-21T04:30:00.000Z'};
 assert.equal((await call('POST',`/machines/${m.id}/bookings`,owner.token,maintenancePayload)).status,409);
 await ok('PUT',`/provider/machines/${m.id}/availability`,provider.token,{day:'2030-04-21',state:'AVAILABLE'});
 await ok('POST',`/machines/${m.id}/bookings`,owner.token,maintenancePayload,201);
 const rows=await ok('GET','/bookings',owner.token);assert.equal(rows.length,5);
 const calendar=await ok('GET',`/provider/machines/${m.id}/calendar?month=2030-04`,provider.token);assert.equal(calendar.days[0].state,'AVAILABLE');
 assert.equal((await call('PUT',`/provider/machines/${m.id}/availability`,provider.token,{day:'2020-01-01',state:'AVAILABLE'})).status,400);
});


test('owner cancellation releases confirmed intervals and remains visible to both participants',async()=>{
 assert.equal((await call('POST',`/bookings/${first.id}/cancel`,provider.token,{expected_version:first.version})).status,403);
 const cancelled=await ok('POST',`/bookings/${first.id}/cancel`,owner.token,{expected_version:first.version});
 assert.equal(cancelled.status,'CANCELLED');
 const sameInterval=await ok('POST',`/machines/${m.id}/bookings`,owner.token,payload(),201);
 const confirmed=await ok('POST',`/bookings/${sameInterval.id}/accept`,provider.token,{expected_version:sameInterval.version});assert.equal(confirmed.status,'CONFIRMED');
 const history=await ok('GET',`/bookings/${first.id}`,provider.token);assert.equal(history.status,'CANCELLED');
 const publicCalendar=await ok('GET',`/machines/${m.id}/calendar?month=2030-04`,owner.token);
 assert.equal(publicCalendar.days[0].day,'2030-04-21');assert.equal(publicCalendar.reserved.length,2);
 assert.equal(JSON.stringify(publicCalendar).includes('owner_user_id'),false);
});
