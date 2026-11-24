const pool = require('../config/db');
const wrap = fn => async (req,res) => {
  try { await fn(req,res); } catch (error) {
    console.error('Fertilizer operation failed:', error.code || error.name);
    res.status(error.code === '42P01' ? 503 : 500).json({message: error.code === '42P01'
      ? 'Fertilizer orders are not configured yet.' : 'Could not update fertilizer orders. Please retry.'});
  }
};
const supplierRoles = ['FERTILIZER_SUPPLIER','CDO'];
exports.suppliers = wrap(async (req,res) => {
  const role = req.query.government === 'true' ? 'CDO' : 'FERTILIZER_SUPPLIER';
  const result = await pool.query('SELECT id,name,location,phone FROM users WHERE role=$1 ORDER BY name',[role]);
  res.json(result.rows);
});

const chatRoles = ['ESTATE_OWNER', 'FERTILIZER_SUPPLIER'];

async function chatParticipants(req, res) {
  const id = Number(req.params.counterparty);
  if (!Number.isSafeInteger(id) || id < 1 || id === req.user.id) {
    res.status(400).json({message: 'Choose a valid chat contact'});
    return null;
  }
  const owner = req.user.role === 'ESTATE_OWNER';
  const result = await pool.query('SELECT id, name FROM users WHERE id=$1 AND role=$2',
    [id, owner ? 'FERTILIZER_SUPPLIER' : 'ESTATE_OWNER']);
  if (!result.rows.length) {
    res.status(404).json({message: 'Fertilizer chat contact not found'});
    return null;
  }
  return {ids: owner ? [req.user.id, id] : [id, req.user.id], contact: result.rows[0]};
}

exports.chatThreads = wrap(async (req, res) => {
  if (!chatRoles.includes(req.user.role)) return res.status(403).json({message: 'This account cannot use supplier chat'});
  const owner = req.user.role === 'ESTATE_OWNER';
  const ownColumn = owner ? 'owner_user_id' : 'supplier_user_id';
  const contactColumn = owner ? 'supplier_user_id' : 'owner_user_id';
  const {rows} = await pool.query(`SELECT u.id, u.name, MAX(m.id) AS latest_message_id
    FROM fertilizer_supplier_messages m JOIN users u ON u.id=m.${contactColumn}
    WHERE m.${ownColumn}=$1 GROUP BY u.id,u.name ORDER BY latest_message_id DESC`, [req.user.id]);
  res.json(rows);
});

exports.chatMessages = wrap(async (req, res) => {
  if (!chatRoles.includes(req.user.role)) return res.status(403).json({message: 'This account cannot use supplier chat'});
  const pair = await chatParticipants(req, res);
  if (!pair) return;
  const {rows} = await pool.query(`SELECT * FROM fertilizer_supplier_messages
    WHERE owner_user_id=$1 AND supplier_user_id=$2 ORDER BY id DESC LIMIT 200`, pair.ids);
  res.json({contact: pair.contact, messages: rows.reverse()});
});

exports.sendChatMessage = wrap(async (req, res) => {
  if (!chatRoles.includes(req.user.role)) return res.status(403).json({message: 'This account cannot use supplier chat'});
  const message = typeof req.body?.message === 'string' ? req.body.message.trim() : '';
  if (!message || message.length > 2000) return res.status(400).json({message: 'Enter a message of up to 2,000 characters'});
  const pair = await chatParticipants(req, res);
  if (!pair) return;
  const {rows} = await pool.query(`INSERT INTO fertilizer_supplier_messages
    (owner_user_id,supplier_user_id,sender_user_id,message) VALUES ($1,$2,$3,$4) RETURNING *`,
    [...pair.ids, req.user.id, message]);
  res.status(201).json(rows[0]);
});
exports.create = wrap(async (req,res) => {
  const {supplier_id,product,quantity,proposed_total,preferred_date,time_slot} = req.body;
  if(!Number.isInteger(supplier_id)||!Number.isInteger(quantity)||quantity<1||quantity>100000||
     typeof product!=='string'||!product.trim()||product.length>2000||
     typeof proposed_total!=='number'||!Number.isFinite(proposed_total)||proposed_total<0||proposed_total>100000000||
     typeof time_slot!=='string'||!time_slot.trim()||time_slot.length>100||
     typeof preferred_date!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(preferred_date)||
     Number.isNaN(Date.parse(preferred_date))||new Date(preferred_date).toISOString().slice(0,10)!==preferred_date) {
    return res.status(400).json({message:'Enter a supplier, products, bag quantity, valid total, date and time slot'});
  }
  const supplier = (await pool.query('SELECT role FROM users WHERE id=$1',[supplier_id])).rows[0];
  if(!supplier||!supplierRoles.includes(supplier.role)||supplier_id===req.user.id)
    return res.status(400).json({message:'Choose a registered fertilizer supplier or CDO'});
  const application=req.body.application ?? null;
  if(application !== null && (typeof application !== 'object' || Array.isArray(application) || JSON.stringify(application).length > 14000000))
    return res.status(400).json({message:'The application is too large or invalid'});
  if(supplier.role==='CDO' && (!application || !['nic_copy','land_title_copy'].every(key =>
    typeof application[key]==='string' && application[key].length>0 && application[key].length<=7000000 && /^[A-Za-z0-9+/]+={0,2}$/.test(application[key]))))
    return res.status(400).json({message:'Attach the identity card and land title images (up to 5 MB each)'});
  const result=await pool.query(`INSERT INTO fertilizer_orders
    (owner_user_id,supplier_user_id,product,quantity,proposed_total,preferred_date,time_slot,application)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
    [req.user.id,supplier_id,product.trim(),quantity,proposed_total,preferred_date,time_slot.trim(),application === null ? null : JSON.stringify(application)]);
  res.status(201).json(result.rows[0]);
});
exports.list = wrap(async (req,res) => {
  const result=await pool.query(`SELECT f.*,o.name AS owner_name,s.name AS supplier_name
    FROM fertilizer_orders f JOIN users o ON o.id=f.owner_user_id JOIN users s ON s.id=f.supplier_user_id
    WHERE f.owner_user_id=$1 OR f.supplier_user_id=$1 ORDER BY f.created_at DESC,f.id DESC`,[req.user.id]);
  res.json(result.rows);
});
exports.transition = wrap(async (req,res) => {
  const order=(await pool.query('SELECT * FROM fertilizer_orders WHERE id=$1',[req.params.id])).rows[0];
  if(!order||![order.owner_user_id,order.supplier_user_id].includes(req.user.id))
    return res.status(404).json({message:'Order not found'});
  const action=req.params.action;
  const isSupplier=order.supplier_user_id===req.user.id&&supplierRoles.includes(req.user.role);
  if(action==='confirm-receipt') {
    if(order.owner_user_id!==req.user.id) return res.status(403).json({message:'Only the land owner can confirm receipt'});
    const result=await pool.query(`UPDATE fertilizer_orders SET receipt_confirmed_at=$2
      WHERE id=$1 AND status='DELIVERED' AND receipt_confirmed_at IS NULL RETURNING *`,[order.id,new Date()]);
    if(!result.rows.length) return res.status(409).json({message:'The order must be delivered and awaiting receipt'});
    return res.json(result.rows[0]);
  }
  if(action==='cancel') {
    const {reason,note=''}=req.body;
    if(typeof reason!=='string'||!reason.trim()||reason.length>200||typeof note!=='string'||note.length>500)
      return res.status(400).json({message:'Choose a cancellation reason and enter an optional note'});
    const result=await pool.query(`UPDATE fertilizer_orders SET status='CANCELLED',cancel_reason=$2,cancel_note=$3,
      cancelled_by=$4,cancelled_at=$5 WHERE id=$1 AND status IN ('PENDING','ACCEPTED','DELIVERED')
      AND receipt_confirmed_at IS NULL RETURNING *`,[order.id,reason.trim(),note.trim()||null,req.user.id,new Date()]);
    if(!result.rows.length) return res.status(409).json({message:'This order cannot be cancelled'});
    return res.json(result.rows[0]);
  }
  if(!['accept','deliver'].includes(action)) return res.status(400).json({message:'Unknown order action'});
  if(!isSupplier) return res.status(403).json({message:'Only the assigned supplier can update delivery'});
  const next={accept:'ACCEPTED',deliver:'DELIVERED',cancel:'CANCELLED'}[action];
  const allowed=action==='deliver'?['ACCEPTED']:action==='accept'?['PENDING']:['PENDING','ACCEPTED'];
  if(!allowed.includes(order.status)) return res.status(409).json({message:'The order has changed. Refresh before responding.'});
  const result=await pool.query(`UPDATE fertilizer_orders SET status=$2,delivered_at=$3
    WHERE id=$1 AND status=$4 RETURNING *`,[order.id,next,action==='deliver'?new Date():null,order.status]);
  if(!result.rows.length) return res.status(409).json({message:'The order has changed. Refresh and retry.'});
  res.json(result.rows[0]);
});
exports.rateOwner = wrap(async (req,res) => {
  const rating=req.body.rating;
  if(!Number.isInteger(rating)||rating<1||rating>5) return res.status(400).json({message:'Choose a rating from 1 to 5 stars'});
  const order=(await pool.query('SELECT * FROM fertilizer_orders WHERE id=$1 AND (supplier_user_id=$2 OR owner_user_id=$2)',[req.params.id,req.user.id])).rows[0];
  if(!order) return res.status(404).json({message:'Order not found'});
  const column=order.owner_user_id===req.user.id?'supplier_rating':'land_owner_rating';
  if(order.status!=='DELIVERED'||!order.receipt_confirmed_at)
    return res.status(409).json({message:'Ratings are available after receipt is confirmed'});
  const ratedAt=column==='land_owner_rating'?',rated_at=$3':'';
  const params=column==='land_owner_rating'?[order.id,rating,new Date()]:[order.id,rating];
  const result=await pool.query(`UPDATE fertilizer_orders SET ${column}=$2${ratedAt}
    WHERE id=$1 AND status='DELIVERED' AND receipt_confirmed_at IS NOT NULL AND ${column} IS NULL RETURNING *`,params);
  if(!result.rows.length) return res.status(409).json({message:'This order has already been rated'});
  res.json(result.rows[0]);
});
