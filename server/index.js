const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const axios = require('axios');
const nodemailer = require('nodemailer');

const app = express();
app.use(cors());
app.use(bodyParser.json());

const PORT = process.env.PORT || 3000;
const GLOBAL_PARENT_WEBHOOK = process.env.PARENT_WEBHOOK_URL || null;

// ── SMTP Config for password reset emails ──
const SMTP_USER = process.env.SMTP_USER || 'recoverysuraksha@gmail.com';
const SMTP_PASS = process.env.SMTP_PASS || 'zkirbqvsmoaiqehf';

let transporter = null;
try {
  transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: SMTP_USER,
      pass: SMTP_PASS,
    },
  });
} catch (e) {
  console.error('Failed to create SMTP transporter:', e.message);
}

// ── Health check ──
app.get('/', (req, res) => res.send('Device Sync Server OK'));

// ── Send password reset email ──
app.post('/send-reset-email', async (req, res) => {
  const { email, password } = req.body || {};

  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }

  try {
    const mailOptions = {
      from: process.env.SMTP_FROM || process.env.SMTP_USER || 'noreply@suraksha.app',
      to: email,
      subject: 'Suraksha - Your New Password',
      html: `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 30px; background: #f8f9fa; border-radius: 12px;">
          <div style="text-align: center; margin-bottom: 24px;">
            <div style="display: inline-block; background: #4B39EF; color: white; padding: 12px 24px; border-radius: 8px; font-size: 22px; font-weight: bold;">
              Suraksha
            </div>
          </div>
          <div style="background: white; padding: 28px; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.06);">
            <h2 style="color: #333; margin: 0 0 16px 0; font-size: 20px;">Password Reset</h2>
            <p style="color: #555; margin: 0 0 20px 0; line-height: 1.6;">
              Your password has been reset. Here is your new temporary password:
            </p>
            <div style="background: #f0eeff; border: 2px dashed #4B39EF; border-radius: 8px; padding: 16px; text-align: center; margin: 0 0 20px 0;">
              <span style="font-size: 28px; font-weight: bold; letter-spacing: 4px; color: #4B39EF; font-family: monospace;">
                ${password}
              </span>
            </div>
            <p style="color: #555; margin: 0 0 8px 0; line-height: 1.6;">
              Please log in with this password and consider changing it in your settings.
            </p>
            <p style="color: #999; font-size: 12px; margin: 20px 0 0 0;">
              If you did not request a password reset, please ignore this email or contact support.
            </p>
          </div>
          <p style="color: #aaa; font-size: 11px; text-align: center; margin: 16px 0 0 0;">
            &copy; ${new Date().getFullYear()} Suraksha. All rights reserved.
          </p>
        </div>
      `,
      text: `Suraksha - Password Reset\n\nYour new password is: ${password}\n\nPlease log in with this password and consider changing it in your settings.\n\nIf you did not request this, please ignore this email.`,
    };

    await transporter.sendMail(mailOptions);
    console.log(`Password reset email sent to ${email}`);
    return res.status(200).json({ success: true, message: 'Email sent successfully' });
  } catch (err) {
    console.error('Failed to send reset email:', err.message || err);
    return res.status(500).json({ error: 'Failed to send email', details: err.message });
  }
});

// ── Device sync endpoint ──
app.post('/sync', async (req, res) => {
  const { deviceId, events, parentWebhookUrl } = req.body || {};

  if (!deviceId || !events) {
    return res.status(400).json({ error: 'deviceId and events required' });
  }

  console.log('Received events from', deviceId, events.length);

  const webhook = parentWebhookUrl || GLOBAL_PARENT_WEBHOOK;

  if (!webhook) {
    return res.status(202).json({ status: 'received', note: 'no parent webhook configured' });
  }

  const forwardPayload = { deviceId, events, receivedAt: new Date().toISOString() };

  try {
    await axios.post(webhook, forwardPayload, { timeout: 5000 });
    return res.status(200).json({ status: 'forwarded' });
  } catch (err) {
    console.error('Forward to parent failed:', err.message || err);
    try {
      await axios.post(webhook, forwardPayload, { timeout: 5000 });
      return res.status(200).json({ status: 'forwarded_on_retry' });
    } catch (err2) {
      console.error('Retry failed:', err2.message || err2);
      return res.status(502).json({ status: 'failed_to_forward' });
    }
  }
});

app.listen(PORT, () => {
  console.log(`Suraksha Server listening on port ${PORT}`);
});