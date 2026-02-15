const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.static('public'));
app.use(express.json());
app.get('/routing-data',(req,res)=>{res.sendFile(__dirname+'/complete_routing_system1.0.html');});

let orders = [];

app.get('/orders', (req, res) => {
  res.json(orders);
});

app.post('/new-order', (req, res) => {
  const { pickup, material, dropoff, time, driver, loads } = req.body;
  if (!pickup || !material || !dropoff || !time) {
    return res.status(400).json({ error: 'Missing required fields.' });
  }
  orders.push({
    pickup,
    material,
    dropoff,
    time,
    driver: driver || '—',
    loads: loads || 1
  });
  res.json({ status: 'Order added' });
});

app.listen(PORT, () => {
  console.log(`🚛 Order server running on port ${PORT}`);
});