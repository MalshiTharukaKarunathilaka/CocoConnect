const router = require('express').Router();
const {requireAuth,requireRole} = require('../middleware/auth');
const c = require('../controllers/fertilizerController');
router.use(requireAuth);
router.param('id', (req,res,next,value) => {
  if(!/^\d+$/.test(value)||!Number.isSafeInteger(Number(value))||Number(value)<1) return res.status(400).json({message:'Invalid order ID'});
  next();
});
router.get('/suppliers',requireRole('ESTATE_OWNER'),c.suppliers);
router.get('/chats',c.chatThreads);
router.get('/chats/:counterparty',c.chatMessages);
router.post('/chats/:counterparty',c.sendChatMessage);
router.post('/orders',requireRole('ESTATE_OWNER'),c.create);
router.get('/orders',c.list);
router.put('/orders/:id/rating',c.rateOwner);
router.post('/orders/:id/:action',c.transition);
module.exports=router;
