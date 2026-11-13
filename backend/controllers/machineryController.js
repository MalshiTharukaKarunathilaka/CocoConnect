const pool = require('../config/db');
const catalog = {
  Tractor: {Slasher:['acre'], 'Disc Ploughing':['acre'], Rotary:['acre'], 'Koku Nagula':['acre'], Trailer:['day']},
  Backhoe: {'Small Backhoe':['hour'], 'Large Backhoe':['hour']},
  'Hand Tractor': {'Hand Tractor':['day']},
};
class Failure extends Error { constructor(status,message){ super(message);this.status=status; } }
const fail = (status,message) => { throw new Failure(status,message); };
const id = value => { if(typeof value==='boolean'||value==null) fail(400,'Invalid record ID');const n=Number(value);if(!Number.isInteger(n)||n<1) fail(400,'Invalid record ID');return n; };
const positive = value => { if(!['string','number'].includes(typeof value)) fail(400,'Enter a valid amount');const n=Number(value);if(!Number.isFinite(n)||n<=0||n>100000000) fail(400,'Enter a positive amount up to 100,000,000');return n; };
const money = value => Math.round(positive(value)*100)/100;
const text = (value,label,max=2000) => { if(typeof value!=='string'||!value.trim()||value.trim().length>max) fail(400,`${label} is required (maximum ${max} characters)`);return value.trim(); };
const dayOf = value => new Date(new Date(value).getTime()+330*60000).toISOString().slice(0,10);
const dayStart = value => new Date(`${value}T00:00:00+05:30`);
const validDay = value => { if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value)||Number.isNaN(Date.parse(value))||new Date(value).toISOString().slice(0,10)!==value) fail(400,'Use a valid date');return value; };
const wrap = fn => async(req,res) => { try {await fn(req,res);}catch(error){
  if(error.code==='42P01') return res.status(503).json({message:'Machinery database setup is pending. Contact the project administrator.'});
  if(error.code==='23P01') return res.status(409).json({message:'This machine has already been booked for that time slot.'});
  if(error.code==='23505') return res.status(409).json({message:'This record already exists. Refresh and try again.'});
  if(!error.status) console.error('Machinery operation failed:',error.code||error.name);
  return res.status(error.status||500).json({message:error.status?error.message:'The machinery operation could not be completed. Please try again.'});
}};
const transaction = async fn => { const db=await pool.connect();try{await db.query('BEGIN');const result=await fn(db);await db.query('COMMIT');return result;}catch(error){await db.query('ROLLBACK');throw error;}finally{db.release();} };
const profile = async(db,userId) => {const r=await db.query('SELECT * FROM service_providers WHERE user_id=$1',[userId]);if(!r.rows[0]) fail(403,'Complete your machinery provider registration first');return r.rows[0];};
const machine = async(db,machineId,userId,lock=false) => {
  const r=await db.query(`SELECT m.*,p.user_id AS provider_user_id FROM machinery m JOIN service_providers p ON p.id=m.provider_id WHERE m.id=$1`,[id(machineId)]);
  const m=r.rows[0];if(!m || (userId!=null&&m.provider_user_id!==userId)) fail(404,'Machinery not found');
  if(lock) await db.query('SELECT id FROM machinery WHERE id=$1 FOR UPDATE',[m.id]);
  return m;
};
const booking = async(db,bookingId,user,lock=false) => {
  if(!['SERVICE_PROVIDER','ESTATE_OWNER'].includes(user.role)) fail(403,'This account cannot access machinery bookings');
  let r=await db.query('SELECT * FROM machinery_bookings WHERE id=$1',[id(bookingId)]);
  let b=r.rows[0];if(!b) fail(404,'Booking not found');
  const m=await machine(db,b.machine_id,null,lock);
  if(m.provider_user_id!==user.id&&b.owner_user_id!==user.id) fail(404,'Booking not found');
  if(lock){r=await db.query('SELECT * FROM machinery_bookings WHERE id=$1 FOR UPDATE',[b.id]);b=r.rows[0];}
  return {...b,provider_user_id:m.provider_user_id};
};
const checkVersion = (b,body) => {if(!Number.isInteger(body.expected_version)||body.expected_version!==b.version) fail(409,'This request changed. Refresh it before responding.');if(b.status!=='PENDING') fail(409,'This request is no longer pending');};
const available = async(db,m,start,end,exceptId=0) => {
  const startDay=dayOf(start);const endDay=dayOf(new Date(new Date(end).getTime()-1));
  const blocked=await db.query("SELECT id FROM machinery_availability WHERE machine_id=$1 AND day >= $2 AND day <= $3 AND state <> 'AVAILABLE'",[m.id,startDay,endDay]);
  if(blocked.rows.length) fail(409,'This machinery is unavailable or under maintenance on the requested date.');
  const overlap=await db.query("SELECT id FROM machinery_bookings WHERE machine_id=$1 AND status='CONFIRMED' AND starts_at < $2 AND ends_at > $3 AND id <> $4",[m.id,end,start,exceptId]);
  if(overlap.rows.length) fail(409,'This machinery is already booked for that time slot.');
};
const MONTHS=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const WEEKDAYS=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
const clock12 = d => {const h=d.getUTCHours();const m=String(d.getUTCMinutes()).padStart(2,'0');return `${String(h%12===0?12:h%12).padStart(2,'0')}:${m} ${h<12?'AM':'PM'}`;};
// "Fri, 6 Nov 2026 - 07:30 AM to 12:00 PM" in Sri Lankan time.
const whenText = (start,end) => {
  const s=new Date(new Date(start).getTime()+330*60000);const e=new Date(new Date(end).getTime()+330*60000);
  const sameDay=s.toISOString().slice(0,10)===e.toISOString().slice(0,10);
  const day=d=>`${WEEKDAYS[d.getUTCDay()]}, ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
  return sameDay?`${day(s)} - ${clock12(s)} to ${clock12(e)}`:`${day(s)} ${clock12(s)} to ${day(e)} ${clock12(e)}`;
};
// Offers are saved with the service date, so each offer card shows the date it was made for.
const addMessage = (db,b,userId,message,offer=null) => db.query('INSERT INTO machinery_messages(booking_id,sender_id,message,offer_total) VALUES ($1,$2,$3,$4)',[b.id,userId,offer===null?message:`${message}\nService date: ${whenText(b.starts_at,b.ends_at)}`,offer]);
const details = async(db,bookingId,user) => {
  const b=await booking(db,bookingId,user);
  const m=await machine(db,b.machine_id);
  const people=await db.query('SELECT id,name,phone,latitude,longitude FROM users WHERE id=$1 OR id=$2',[b.owner_user_id,m.provider_user_id]);
  const owner=people.rows.find(u=>u.id===b.owner_user_id);const provider=people.rows.find(u=>u.id===m.provider_user_id);
  const items=(await db.query('SELECT * FROM machinery_booking_items WHERE booking_id=$1 ORDER BY id',[b.id])).rows;
  const messages=(await db.query('SELECT * FROM machinery_messages WHERE booking_id=$1 ORDER BY id',[b.id])).rows;
  return {...b,machine_name:m.name,machinery:m.category,owner,provider,items,messages};
};

exports.catalog = wrap(async(_req,res)=>res.json(catalog));
exports.providerMachines = wrap(async(req,res)=>{
  const p=await profile(pool,req.user.id);
  const rows=(await pool.query('SELECT * FROM machinery WHERE provider_id=$1 ORDER BY id',[p.id])).rows;
  for(const row of rows) row.services=(await pool.query('SELECT * FROM machinery_services WHERE machine_id=$1 ORDER BY id',[row.id])).rows;
  res.json(rows);
});
exports.createMachine = wrap(async(req,res)=>{
  const p=await profile(pool,req.user.id);const category=req.body.category;
  if(!catalog[category]) fail(400,'Choose Tractor, Backhoe or Hand Tractor');
  const name=text(req.body.name,'Machine name',120);
  const result=await transaction(async db=>{
    // Serialize additions for this provider so simultaneous requests cannot add duplicates.
    await db.query('SELECT id FROM service_providers WHERE id=$1 FOR UPDATE',[p.id]);
    const existing=await db.query('SELECT id FROM machinery WHERE provider_id=$1 AND category=$2',[p.id,category]);
    if(existing.rows.length) fail(409,`You already have a ${category}. Only one machine of each type is allowed.`);
    return db.query('INSERT INTO machinery(provider_id,name,category) VALUES ($1,$2,$3) RETURNING *',[p.id,name,category]);
  });
  res.status(201).json(result.rows[0]);
});
exports.saveRate = wrap(async(req,res)=>{
  const m=await machine(pool,req.params.machineId,req.user.id);
  const name=req.body.name;const unit=req.body.unit;
  if(!catalog[m.category]?.[name]?.includes(unit)) fail(400,'Choose a valid service and pricing unit for this machinery');
  const result=await pool.query(`INSERT INTO machinery_services(machine_id,name,unit,rate) VALUES ($1,$2,$3,$4)
    ON CONFLICT (machine_id,name) DO UPDATE SET unit=EXCLUDED.unit,rate=EXCLUDED.rate RETURNING *`,[m.id,name,unit,money(req.body.rate)]);
  res.json(result.rows[0]);
});
exports.calendar = wrap(async(req,res)=>{
  const m=await machine(pool,req.params.machineId,req.user.id);
  const month=String(req.query.month||'');if(!/^\d{4}-\d{2}$/.test(month)) fail(400,'Use month YYYY-MM');
  const first=validDay(`${month}-01`);const next=new Date(first);next.setUTCMonth(next.getUTCMonth()+1);
  const end=next.toISOString().slice(0,10);
  const days=(await pool.query('SELECT * FROM machinery_availability WHERE machine_id=$1 AND day >= $2 AND day < $3',[m.id,first,end])).rows;
  const rows=(await pool.query('SELECT id FROM machinery_bookings WHERE machine_id=$1 AND starts_at < $2 AND ends_at > $3 ORDER BY starts_at',[m.id,dayStart(end),dayStart(first)])).rows;
  const bookings=[];for(const row of rows) bookings.push(await details(pool,row.id,req.user));
  const services=(await pool.query('SELECT * FROM machinery_services WHERE machine_id=$1 ORDER BY id',[m.id])).rows;
  res.json({machine:m,days:days.map(row=>({...row,day:typeof row.day==='string'?row.day.slice(0,10):row.day.toISOString().slice(0,10)})),bookings,services});
});
exports.setAvailability = wrap(async(req,res)=>{
  const day=validDay(req.body.day);if(day<dayOf(new Date())) fail(400,'Past availability cannot be changed');
  const state=req.body.state;if(!['AVAILABLE','UNAVAILABLE','MAINTENANCE'].includes(state)) fail(400,'Invalid availability state');
  const result=await transaction(async db=>{
    const m=await machine(db,req.params.machineId,req.user.id,true);
    if(state!=='AVAILABLE') {
      const end=new Date(dayStart(day).getTime()+86400000);
      const found=await db.query("SELECT id FROM machinery_bookings WHERE machine_id=$1 AND status='CONFIRMED' AND starts_at < $2 AND ends_at > $3",[m.id,end,dayStart(day)]);
      if(found.rows.length) fail(409,'This date has confirmed bookings. Availability cannot invalidate them.');
    }
    return (await db.query(`INSERT INTO machinery_availability(machine_id,day,state,note) VALUES ($1,$2,$3,$4)
      ON CONFLICT(machine_id,day) DO UPDATE SET state=EXCLUDED.state,note=EXCLUDED.note RETURNING *`,[m.id,day,state,String(req.body.note||'').slice(0,2000)])).rows[0];
  });res.json(result);
});
exports.browse = wrap(async(_req,res)=>{
  const rows=(await pool.query(`SELECT m.*,u.name AS provider_name,u.latitude,u.longitude,p.radius_km FROM machinery m
    JOIN service_providers p ON p.id=m.provider_id JOIN users u ON u.id=p.user_id WHERE m.active=true ORDER BY m.id`)).rows;
  for(const row of rows) row.services=(await pool.query('SELECT * FROM machinery_services WHERE machine_id=$1 ORDER BY id',[row.id])).rows;
  res.json(rows.filter(row=>row.services.length>0));
});
exports.createBooking = wrap(async(req,res)=>{
  const start=new Date(req.body.starts_at);const end=new Date(req.body.ends_at);
  if(Number.isNaN(+start)||Number.isNaN(+end)||end<=start||start<=new Date()||end-start>31*86400000) fail(400,'Choose a future start time and a later end time (maximum 31 days)');
  const estate=text(req.body.estate_name,'Estate name',160);const address=text(req.body.address,'Estate address');
  const items=req.body.items;if(!Array.isArray(items)||!items.length||items.length>20) fail(400,'Select between 1 and 20 services');
  const result=await transaction(async db=>{
    const m=await machine(db,req.params.machineId,null,true);if(!m.active) fail(409,'This machinery is not accepting requests');
    if(m.provider_user_id===req.user.id) fail(403,'You cannot book your own machinery');
    await available(db,m,start,end);
    const stored=[];const seen=new Set();let total=0;
    for(const item of items){
      const serviceId=id(item.service_id);if(seen.has(serviceId)) fail(400,'A service may only appear once');seen.add(serviceId);
      const service=(await db.query('SELECT * FROM machinery_services WHERE id=$1 AND machine_id=$2',[serviceId,m.id])).rows[0];
      if(!service) fail(400,'Selected service does not belong to this machine');
      const quantity=positive(item.quantity);if(Math.abs(quantity*100-Math.round(quantity*100))>0.00001) fail(400,'Use at most two decimal places for quantities');if(service.unit==='day'&&!Number.isInteger(quantity)) fail(400,'Day quantities must be whole days');
      if(service.unit==='hour'&&quantity>(end-start)/3600000) fail(400,'Requested hours exceed the selected time interval');
      if(service.unit==='day'&&quantity>Math.ceil((end-start)/86400000)) fail(400,'Requested days exceed the selected interval');
      stored.push({...service,quantity});total+=Number(service.rate)*quantity;
    }
    total=req.body.offered_total==null?money(total):money(req.body.offered_total);
    const owner=(await db.query('SELECT latitude,longitude FROM users WHERE id=$1',[req.user.id])).rows[0];
    const b=(await db.query(`INSERT INTO machinery_bookings(machine_id,owner_user_id,estate_name,address,latitude,longitude,starts_at,ends_at,proposed_total,proposed_by)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,[m.id,req.user.id,estate,address,owner?.latitude,owner?.longitude,start,end,total,req.user.id])).rows[0];
    for(const item of stored) await db.query('INSERT INTO machinery_booking_items(booking_id,service_id,name,unit,quantity,rate) VALUES ($1,$2,$3,$4,$5,$6)',[b.id,item.id,item.name,item.unit,item.quantity,item.rate]);
    await addMessage(db,b,req.user.id,'Booking requested.',total);return b;
  });res.status(201).json(await details(pool,result.id,req.user));
});
exports.myBookings = wrap(async(req,res)=>{
  const rows=(await pool.query('SELECT id FROM machinery_bookings WHERE owner_user_id=$1 ORDER BY starts_at DESC',[req.user.id])).rows;
  const result=[];for(const row of rows) result.push(await details(pool,row.id,req.user));res.json(result);
});
exports.getBooking = wrap(async(req,res)=>res.json(await details(pool,req.params.bookingId,req.user)));
exports.message = wrap(async(req,res)=>{
  await transaction(async db=>{
    const b=await booking(db,req.params.bookingId,req.user,true);checkVersion(b,req.body);
    if(b.provider_user_id===req.user.id) fail(403,'Providers can only accept or decline a request. The estate owner sends the offers.');
    const offer=req.body.offer_total==null?null:money(req.body.offer_total);
    const message=req.body.message?text(req.body.message,'Message'):offer?'Proposed a new price.':fail(400,'Enter a message or counteroffer');
    await addMessage(db,b,req.user.id,message,offer);
    if(offer!==null) await db.query('UPDATE machinery_bookings SET proposed_total=$2,proposed_by=$3,offer_agreed=false,version=version+1 WHERE id=$1',[b.id,offer,req.user.id]);
    else await db.query('UPDATE machinery_bookings SET version=version+1 WHERE id=$1',[b.id]);
  });res.status(201).json(await details(pool,req.params.bookingId,req.user));
});
exports.revise = wrap(async(req,res)=>{
  await transaction(async db=>{
    const b=await booking(db,req.params.bookingId,req.user,true);checkVersion(b,req.body);
    if(b.owner_user_id!==req.user.id) fail(403,'Only the requesting estate owner can change this request');
    const m=await machine(db,b.machine_id,null,true);if(!m.active) fail(409,'This machinery is not accepting requests');
    const start=req.body.starts_at==null?new Date(b.starts_at):new Date(req.body.starts_at);
    const end=req.body.ends_at==null?new Date(b.ends_at):new Date(req.body.ends_at);
    if(Number.isNaN(+start)||Number.isNaN(+end)||end<=start||start<=new Date()||end-start>31*86400000) fail(400,'Choose a future start time and a later end time (maximum 31 days)');
    const timeChanged=+start!==+new Date(b.starts_at)||+end!==+new Date(b.ends_at);
    const existing=(await db.query('SELECT * FROM machinery_booking_items WHERE booking_id=$1 ORDER BY id',[b.id])).rows;
    let wanted=existing.map(i=>({service_id:i.service_id,name:i.name,unit:i.unit,quantity:Number(i.quantity),rate:Number(i.rate)}));
    let itemsChanged=false;
    if(req.body.items!==undefined){
      const items=req.body.items;if(!Array.isArray(items)||!items.length||items.length>20) fail(400,'Select between 1 and 20 services');
      const seen=new Set();wanted=[];
      for(const item of items){
        const serviceId=id(item.service_id);if(seen.has(serviceId)) fail(400,'A service may only appear once');seen.add(serviceId);
        const kept=existing.find(i=>i.service_id===serviceId);
        const service=kept||(await db.query('SELECT * FROM machinery_services WHERE id=$1 AND machine_id=$2',[serviceId,m.id])).rows[0];
        if(!service) fail(400,'Selected service does not belong to this machine');
        wanted.push({service_id:serviceId,name:service.name,unit:service.unit,quantity:positive(item.quantity),rate:Number(service.rate)});
      }
      const key=list=>JSON.stringify(list.map(i=>[i.service_id,Number(i.quantity)]).sort((a,c)=>a[0]-c[0]));
      itemsChanged=key(wanted)!==key(existing.map(i=>({service_id:i.service_id,quantity:Number(i.quantity)})));
    }
    let listTotal=0;
    for(const i of wanted){
      if(Math.abs(i.quantity*100-Math.round(i.quantity*100))>0.00001) fail(400,'Use at most two decimal places for quantities');
      if(i.unit==='day'&&!Number.isInteger(i.quantity)) fail(400,'Day quantities must be whole days');
      if(i.unit==='hour'&&i.quantity>(end-start)/3600000) fail(400,'Requested hours exceed the selected time interval');
      if(i.unit==='day'&&i.quantity>Math.ceil((end-start)/86400000)) fail(400,'Requested days exceed the selected interval');
      listTotal+=i.rate*i.quantity;
    }
    const offer=req.body.offer_total!=null?money(req.body.offer_total):(itemsChanged?money(listTotal):Number(b.proposed_total));
    const priceChanged=offer!==Number(b.proposed_total);
    if(!timeChanged&&!itemsChanged&&!priceChanged) fail(400,'Nothing was changed. Change the price, the work or the time first.');
    if(timeChanged) await available(db,m,start,end,b.id);
    const updated=(await db.query('UPDATE machinery_bookings SET starts_at=$2,ends_at=$3,proposed_total=$4,proposed_by=$5,offer_agreed=false,version=version+1 WHERE id=$1 RETURNING *',[b.id,start,end,offer,req.user.id])).rows[0];
    if(itemsChanged){
      await db.query('DELETE FROM machinery_booking_items WHERE booking_id=$1',[b.id]);
      for(const i of wanted) await db.query('INSERT INTO machinery_booking_items(booking_id,service_id,name,unit,quantity,rate) VALUES ($1,$2,$3,$4,$5,$6)',[b.id,i.service_id,i.name,i.unit,i.quantity,i.rate]);
    }
    const what=[priceChanged&&'price',itemsChanged&&'work',timeChanged&&'date and time'].filter(Boolean).join(', ');
    const note=req.body.message?text(req.body.message,'Message'):`Changed the ${what}.`;
    await addMessage(db,updated,req.user.id,note,offer);
  });res.json(await details(pool,req.params.bookingId,req.user));
});
exports.agree = wrap(async(req,res)=>{
  await transaction(async db=>{
    const b=await booking(db,req.params.bookingId,req.user,true);checkVersion(b,req.body);
    if(b.proposed_by===req.user.id) fail(409,'The other participant must agree to your proposal');
    await db.query('UPDATE machinery_bookings SET offer_agreed=true,version=version+1 WHERE id=$1',[b.id]);
    await addMessage(db,b,req.user.id,'Agreed to the proposed total.',b.proposed_total);
  });res.json(await details(pool,req.params.bookingId,req.user));
});
exports.accept = wrap(async(req,res)=>{
  await transaction(async db=>{
    const b=await booking(db,req.params.bookingId,req.user,true);checkVersion(b,req.body);
    if(b.provider_user_id!==req.user.id) fail(403,'Only the assigned provider can confirm this booking');
    if(b.proposed_by===req.user.id&&!b.offer_agreed) fail(409,'The estate owner must agree to your counteroffer first');
    if(new Date(b.starts_at)<=new Date()) fail(409,'This requested time has passed');
    const m=await machine(db,b.machine_id,req.user.id,true);if(!m.active) fail(409,'Machinery is inactive');
    await available(db,m,b.starts_at,b.ends_at,b.id);
    await db.query("UPDATE machinery_bookings SET status='CONFIRMED',agreed_total=proposed_total,offer_agreed=true,version=version+1 WHERE id=$1",[b.id]);
    await addMessage(db,b,req.user.id,'Booking confirmed and time slot reserved.',b.proposed_total);
  });res.json(await details(pool,req.params.bookingId,req.user));
});
exports.decline = wrap(async(req,res)=>{
  await transaction(async db=>{
    const b=await booking(db,req.params.bookingId,req.user,true);checkVersion(b,req.body);
    if(b.provider_user_id!==req.user.id) fail(403,'Only the assigned provider can decline this request');
    await db.query("UPDATE machinery_bookings SET status='DECLINED',version=version+1 WHERE id=$1",[b.id]);
    await addMessage(db,b,req.user.id,'Booking request declined.');
  });res.json(await details(pool,req.params.bookingId,req.user));
});
exports.ownerCalendar = wrap(async(req,res)=>{
  const m=await machine(pool,req.params.machineId);
  const month=String(req.query.month||'');if(!/^\d{4}-\d{2}$/.test(month)) fail(400,'Use month YYYY-MM');
  const first=validDay(`${month}-01`);const next=new Date(first);next.setUTCMonth(next.getUTCMonth()+1);const end=next.toISOString().slice(0,10);
  const days=(await pool.query('SELECT day,state FROM machinery_availability WHERE machine_id=$1 AND day >= $2 AND day < $3',[m.id,first,end])).rows;
  const reserved=(await pool.query("SELECT starts_at,ends_at FROM machinery_bookings WHERE machine_id=$1 AND status='CONFIRMED' AND starts_at < $2 AND ends_at > $3",[m.id,dayStart(end),dayStart(first)])).rows;
  res.json({days:days.map(row=>({...row,day:typeof row.day==='string'?row.day.slice(0,10):row.day.toISOString().slice(0,10)})),reserved});
});

exports.cancel = wrap(async(req,res)=>{
  await transaction(async db=>{
    const b=await booking(db,req.params.bookingId,req.user,true);
    if(b.owner_user_id!==req.user.id) fail(403,'Only the requesting estate owner can cancel this booking');
    if(!Number.isInteger(req.body.expected_version)||req.body.expected_version!==b.version) fail(409,'This request changed. Refresh before cancelling.');
    if(!['PENDING','CONFIRMED'].includes(b.status)||new Date(b.starts_at)<=new Date()) fail(409,'This booking can no longer be cancelled.');
    await db.query("UPDATE machinery_bookings SET status='CANCELLED',version=version+1 WHERE id=$1",[b.id]);
    await addMessage(db,b,req.user.id,'Booking cancelled by the estate owner. Time slot released.');
  });res.json(await details(pool,req.params.bookingId,req.user));
});
