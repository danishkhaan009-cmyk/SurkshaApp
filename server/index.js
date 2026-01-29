});
  console.log(`Device Sync Server listening on port ${PORT}`);
app.listen(PORT, () => {

app.get('/', (req, res) => res.send('Device Sync Server OK'));

});
  }
    }
      return res.status(502).json({ status: 'failed_to_forward' });
      // In production: push to persistent queue / DB for later retry
      console.error('Retry failed:', err2.message || err2);
    } catch (err2) {
      return res.status(200).json({ status: 'forwarded_on_retry' });
      await axios.post(webhook, forwardPayload, { timeout: 5000 });
    try {
    // simple retry once
    console.error('Forward to parent failed:', err.message || err);
  } catch (err) {
    return res.status(200).json({ status: 'forwarded' });
    await axios.post(webhook, forwardPayload, { timeout: 5000 });
  try {

  const forwardPayload = { deviceId, events, receivedAt: new Date().toISOString() };
  // Forward the payload to the parent webhook with retries

  }
    return res.status(202).json({ status: 'received', note: 'no parent webhook configured' });
    // In production: store events for later retrieval by parent.
    // No parent configured: accept and return.
  if (!webhook) {
  const webhook = parentWebhookUrl || GLOBAL_PARENT_WEBHOOK;
  // Determine where to notify the parent: request-level webhook or global one

  console.log('Received events from', deviceId, events.length);
  // Persist or enqueue events here (DB / queue). For demo, we just log.

  }
    return res.status(400).json({ error: 'deviceId and events required' });
  if (!deviceId || !events) {
  const { deviceId, events, parentWebhookUrl } = req.body || {};
  // Expected payload: { deviceId: string, events: [...], parentWebhookUrl?: string }
app.post('/sync', async (req, res) => {

const GLOBAL_PARENT_WEBHOOK = process.env.PARENT_WEBHOOK_URL || null;
// configure fallback webhook where parent listens for device updates
const PORT = process.env.PORT || 3000;

app.use(bodyParser.json());
app.use(cors());
const app = express();

const cors = require('cors');
const axios = require('axios');
const bodyParser = require('body-parser');
