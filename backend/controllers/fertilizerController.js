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
  const result = await pool.query('SELECT id,name,location FROM users WHERE role=$1 ORDER BY name',[role]);
  res.json(result.rows);
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
  if(!['accept','deliver','cancel'].includes(action)) return res.status(400).json({message:'Unknown order action'});
  if(action!=='cancel'&&!isSupplier) return res.status(403).json({message:'Only the assigned supplier can update delivery'});
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
  const order=(await pool.query('SELECT * FROM fertilizer_orders WHERE id=$1 AND supplier_user_id=$2',[req.params.id,req.user.id])).rows[0];
  if(!order) return res.status(404).json({message:'Order not found'});
  if(!supplierRoles.includes(req.user.role)||order.owner_user_id===req.user.id)
    return res.status(403).json({message:'Only the assigned supplier can rate the land owner'});
  if(order.status!=='DELIVERED') return res.status(409).json({message:'Ratings are available after delivery'});
  const result=await pool.query(`UPDATE fertilizer_orders SET land_owner_rating=$2,rated_at=$3
    WHERE id=$1 AND status='DELIVERED' AND land_owner_rating IS NULL RETURNING *`,[order.id,rating,new Date()]);
  if(!result.rows.length) return res.status(409).json({message:'This order has already been rated'});
  res.json(result.rows[0]);
});
