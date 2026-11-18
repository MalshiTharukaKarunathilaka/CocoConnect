const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
process.env.DB_MODE='memory';process.env.PORT='5117';process.env.JWT_SECRET='fertilizer-ratings-test';
let server, owner, supplier, cdo, outsider, worker, order;
const base='http://localhost:5117';
async function call(method,path,account,body) {
 const response=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(account?{Authorization:`Bearer ${account.token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)});
 return {status:response.status,data:await response.json()};
}
async function signup(name,phone,role) {
 const result=await call('POST','/api/auth/signup',null,{name,phone,role,password:'secret123',location:'Kurunegala'});
 assert.equal(result.status,201,JSON.stringify(result.data));return result.data;
}
const payload=()=>({supplier_id:supplier.user.id,product:'Coconut fertilizer',quantity:3,proposed_total:15000,preferred_date:'2030-01-01',time_slot:'Morning'});
before(async()=>{const http=require('node:http');const listen=http.Server.prototype.listen;http.Server.prototype.listen=function(...args){server=this;return listen.apply(this,args);};require('../server');http.Server.prototype.listen=listen;
 owner=await signup('Land owner','0772000101','ESTATE_OWNER');supplier=await signup('Fertilizer shop','0772000102','FERTILIZER_SUPPLIER');
 cdo=await signup('CDO','0772000103','CDO');outsider=await signup('Other supplier','0772000104','FERTILIZER_SUPPLIER');worker=await signup('Worker','0772000105','WORKER');
});
after(()=>server.close());
test('land owners and suppliers share a persistent chat scoped to its two participants', async()=>{
 const supplierPath=`/api/fertilizer/chats/${supplier.user.id}`;
 const ownerPath=`/api/fertilizer/chats/${owner.user.id}`;
 assert.equal((await call('POST',supplierPath,worker,{message:'Hello'})).status,403);
 assert.equal((await call('POST',supplierPath,owner,{message:'   '})).status,400);
 assert.equal((await call('POST',supplierPath,owner,{message:'Do you deliver on Friday?'})).status,201);
 assert.equal((await call('POST',ownerPath,supplier,{message:'Yes, we can deliver.'})).status,201);
 const read=await call('GET',supplierPath,owner);
 assert.deepEqual(read.data.messages.map(row=>row.message),['Do you deliver on Friday?','Yes, we can deliver.']);
 assert.equal((await call('GET',ownerPath,supplier)).data.messages.length,2);
 assert.deepEqual((await call('GET',ownerPath,outsider)).data.messages,[]);
 assert.deepEqual((await call('GET','/api/fertilizer/chats',supplier)).data.map(row=>row.id),[owner.user.id]);
 assert.deepEqual((await call('GET','/api/fertilizer/chats',outsider)).data,[]);
});
test('fertilizer orders require a real supplier, valid data and owner authorization',async()=>{
 assert.equal((await call('GET','/api/fertilizer/orders')).status,401);
 assert.equal((await call('POST','/api/fertilizer/orders',supplier,payload())).status,403);
 for(const body of [{...payload(),supplier_id:worker.user.id},{...payload(),quantity:0},{...payload(),proposed_total:-1},{...payload(),preferred_date:'2030-02-30'}])
  assert.equal((await call('POST','/api/fertilizer/orders',owner,body)).status,400);
 const directory=await call('GET','/api/fertilizer/suppliers',owner);assert.equal(directory.status,200);assert.ok(directory.data.some(s=>s.id===supplier.user.id));
 const created=await call('POST','/api/fertilizer/orders',owner,payload());assert.equal(created.status,201);order=created.data;
 assert.equal(order.owner_user_id,owner.user.id);
 assert.ok((await call('GET','/api/fertilizer/orders',supplier)).data.some(o=>o.id===order.id));
 assert.equal((await call('GET','/api/fertilizer/orders',outsider)).data.length,0);
});
test('both fertilizer participants can rate once after receipt confirmation',async()=>{
 const ratingPath=`/api/fertilizer/orders/${order.id}/rating`;
 assert.equal((await call('PUT',ratingPath,supplier,{rating:5})).status,409);
 assert.equal((await call('POST',`/api/fertilizer/orders/${order.id}/accept`,owner)).status,403);
 assert.equal((await call('POST',`/api/fertilizer/orders/${order.id}/accept`,outsider)).status,404);
 assert.equal((await call('POST',`/api/fertilizer/orders/${order.id}/deliver`,supplier)).status,409);
 assert.equal((await call('POST',`/api/fertilizer/orders/${order.id}/accept`,supplier)).status,200);
 assert.equal((await call('POST',`/api/fertilizer/orders/${order.id}/deliver`,supplier)).status,200);
 for(const rating of [0,6,2.5,'5',null]) assert.equal((await call('PUT',ratingPath,supplier,{rating})).status,400);
 assert.equal((await call('PUT',ratingPath,owner,{rating:1})).status,409);
 assert.equal((await call('PUT',ratingPath,supplier,{rating:5})).status,409);
 assert.equal((await call('POST',`/api/fertilizer/orders/${order.id}/confirm-receipt`,supplier)).status,403);
 assert.equal((await call('POST',`/api/fertilizer/orders/${order.id}/confirm-receipt`,owner)).status,200);
 assert.equal((await call('PUT',ratingPath,owner,{rating:4})).data.supplier_rating,4);
 assert.equal((await call('PUT',ratingPath,outsider,{rating:1})).status,404);
 assert.equal((await call('PUT',ratingPath,supplier,{rating:5})).status,200);
 assert.equal((await call('PUT',ratingPath,supplier,{rating:1})).status,409);
 const saved=(await call('GET','/api/fertilizer/orders',owner)).data.find(o=>o.id===order.id);
 assert.equal(saved.land_owner_rating,5);assert.ok(saved.delivered_at);assert.ok(saved.rated_at);
 assert.equal((await call('POST',`/api/fertilizer/orders/${order.id}/cancel`,owner,{reason:'Schedule changed'})).status,409);
});
test('government orders persist their application only for participants',async()=>{
 assert.equal((await call('POST','/api/fertilizer/orders',owner,{...payload(),supplier_id:cdo.user.id})).status,400);
 const result=await call('POST','/api/fertilizer/orders',owner,{...payload(),supplier_id:cdo.user.id,application:{nic_copy:'aW1hZ2U=',land_title_copy:'aW1hZ2U=',declaration_accepted:true}});
 assert.equal(result.status,201);assert.equal(result.data.application.nic_copy,'aW1hZ2U=');
 assert.ok((await call('GET','/api/fertilizer/orders',cdo)).data.some(o=>o.id===result.data.id));
 assert.equal((await call('GET','/api/fertilizer/orders',outsider)).data.length,0);
});
test('profile weights all received ratings equally, includes all coconut types, and isolates users',async()=>{
 const pool=require('../config/db');
 let summary=(await call('GET','/api/owner/summary',owner)).data;
 assert.equal(summary.rating_count,1);assert.equal(summary.average_rating,5);
 for(const [productType,rating] of [['RAW_COCONUT',5],['DEHUSKED_COCONUT',4],['COCONUT_HUSK',3]]) {
  const listing=(await call('POST','/api/owner/listings',owner,{productType,quantity:100,availableDate:'2030-01-01',offerPricePerUnit:120})).data.listing;
  await pool.query("INSERT INTO orders(listing_id,status,buyer_rating) VALUES ($1,'COMPLETED',$2)",[listing.id,rating]);
 }
 const job=(await pool.query(`INSERT INTO day_jobs(estate_owner_id,category,workers_needed,required_date,location,daily_rate,payment_method,status)
   VALUES ($1,'Weeding',1,'2030-01-01','Kurunegala',2000,'Cash','COMPLETED') RETURNING id`,[summary.estate.id])).rows[0];
 const profile=(await pool.query('SELECT id FROM worker WHERE user_id=$1',[worker.user.id])).rows[0];
 await pool.query("INSERT INTO day_job_applications(day_job_id,worker_id,status,estate_owner_rating) VALUES ($1,$2,'COMPLETED',1)",[job.id,profile.id]);
 // Machinery ownership comes from its assigned provider and booking, not a client-supplied owner ID.
 const provider=(await pool.query(`INSERT INTO service_providers(user_id,identity_number,category,district,address,radius_km)
   VALUES ($1,'821940129V','Machinery','Kurunegala','Yard',5) RETURNING id`,[supplier.user.id])).rows[0];
 const machine=(await pool.query("INSERT INTO machinery(provider_id,name,category) VALUES ($1,'Tractor','Tractor') RETURNING id",[provider.id])).rows[0];
 const booking=(await pool.query(`INSERT INTO machinery_bookings(machine_id,owner_user_id,estate_name,address,starts_at,ends_at,status,proposed_total,proposed_by)
   VALUES ($1,$2,'Land','Kurunegala','2020-01-01T00:00:00Z','2020-01-01T01:00:00Z','CONFIRMED',1000,$2) RETURNING id`,[machine.id,owner.user.id])).rows[0];
 await pool.query('INSERT INTO machinery_booking_feedback(booking_id,owner_user_id,provider_user_id,rating) VALUES ($1,$2,$3,2)',[booking.id,owner.user.id,supplier.user.id]);
 summary=(await call('GET','/api/owner/summary',owner)).data;
 assert.equal(summary.rating_count,6);assert.ok(Math.abs(summary.average_rating-20/6)<1e-10);
 assert.deepEqual(summary.rating_sources.map(s=>[s.key,s.rating_count,s.average_rating]),[
  ['coconut_sales',3,4],['day_jobs',1,1],['machinery',1,2],['fertilizer',1,5]]);
 const fresh=await signup('Unrated owner','0772000106','ESTATE_OWNER');
 const empty=(await call('GET','/api/owner/summary',fresh)).data;assert.equal(empty.rating_count,0);assert.equal(empty.average_rating,null);
});
