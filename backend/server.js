require('dotenv').config();

const express = require('express');
const cors = require('cors');
const twilio = require('twilio');
const sqlite3 = require('sqlite3').verbose();

const app = express();

console.log('BATCH 15 SERVER LOADED - SQLITE ENABLED');

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

const client = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

// ===== SQLite Setup =====
const db = new sqlite3.Database('./callnaija.db');

// Create tables
db.serialize(() => {
  db.run(`
    CREATE TABLE IF NOT EXISTS wallet (
      id INTEGER PRIMARY KEY,
      balance REAL,
      currency TEXT
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS call_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      callSid TEXT,
      fromNumber TEXT,
      toNumber TEXT,
      status TEXT,
      duration INTEGER,
      cost REAL,
      createdAt TEXT
    )
  `);

  // Ensure wallet exists
  db.get(`SELECT * FROM wallet WHERE id = 1`, (err, row) => {
    if (!row) {
      db.run(`INSERT INTO wallet (id, balance, currency) VALUES (1, 5.0, 'GBP')`);
    }
  });
});

// ===== In-memory tracking =====
const callStatuses = {};

const RATE_PER_MINUTE = 0.10;
const MINIMUM_BALANCE_TO_CALL = 0.20;

// ===== Routes =====

app.get('/', (req, res) => {
  res.send('CallNaija API is running');
});

// Get wallet
app.get('/wallet', (req, res) => {
  db.get(`SELECT * FROM wallet WHERE id = 1`, (err, row) => {
    if (err) return res.status(500).json({ success: false });

    res.json({
      success: true,
      balance: row.balance.toFixed(2),
      currency: row.currency,
      ratePerMinute: RATE_PER_MINUTE.toFixed(2),
    });
  });
});

// Top up wallet
app.post('/wallet/top-up', (req, res) => {
  const amount = Number(req.body.amount);

  if (!amount || amount <= 0) {
    return res.status(400).json({
      success: false,
      error: 'Invalid amount',
    });
  }

  db.run(
    `UPDATE wallet SET balance = balance + ? WHERE id = 1`,
    [amount],
    function (err) {
      if (err) return res.status(500).json({ success: false });

      db.get(`SELECT balance FROM wallet WHERE id = 1`, (err, row) => {
        res.json({
          success: true,
          balance: row.balance.toFixed(2),
        });
      });
    }
  );
});

// Start call
app.post('/call', async (req, res) => {
  const { callerNumber, receiverNumber } = req.body;

  if (!callerNumber || !receiverNumber) {
    return res.status(400).json({
      success: false,
      error: 'Numbers required',
    });
  }

  db.get(`SELECT balance FROM wallet WHERE id = 1`, async (err, row) => {
    if (row.balance < MINIMUM_BALANCE_TO_CALL) {
      return res.status(402).json({
        success: false,
        error: 'Insufficient balance',
      });
    }

    try {
      const call = await client.calls.create({
        to: callerNumber,
        from: process.env.TWILIO_PHONE_NUMBER,
        statusCallback: `${process.env.BASE_URL}/status`,
        statusCallbackEvent: ['initiated', 'ringing', 'answered', 'completed'],
        statusCallbackMethod: 'POST',
        twiml: `<Response><Dial>${receiverNumber}</Dial></Response>`,
      });

      callStatuses[call.sid] = {
        callSid: call.sid,
        status: 'initiated',
        from: callerNumber,
        to: receiverNumber,
        charged: false,
      };

      res.json({
        success: true,
        sid: call.sid,
        status: 'initiated',
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  });
});

// Status updates
app.post('/status', (req, res) => {
  const callSid = req.body.CallSid;
  const status = req.body.CallStatus;
  const duration = Number(req.body.CallDuration || 0);

  const existing = callStatuses[callSid] || {};

  if (status === 'completed' && !existing.charged) {
    const minutes = Math.max(1, Math.ceil(duration / 60));
    const cost = minutes * RATE_PER_MINUTE;

    db.run(
      `UPDATE wallet SET balance = balance - ? WHERE id = 1`,
      [cost],
      () => {
        db.run(
          `INSERT INTO call_history 
          (callSid, fromNumber, toNumber, status, duration, cost, createdAt)
          VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            callSid,
            existing.from,
            existing.to,
            status,
            duration,
            cost,
            new Date().toISOString(),
          ]
        );
      }
    );

    existing.charged = true;
  }

  callStatuses[callSid] = {
    ...existing,
    status,
    duration,
  };

  res.sendStatus(200);
});

// Call status
app.get('/call-status/:sid', (req, res) => {
  const data = callStatuses[req.params.sid];

  if (!data) {
    return res.status(404).json({ success: false });
  }

  db.get(`SELECT balance FROM wallet WHERE id = 1`, (err, row) => {
    res.json({
      success: true,
      status: data.status,
      duration: data.duration,
      cost: data.cost,
      walletBalance: row.balance.toFixed(2),
    });
  });
});

// Call history
app.get('/call-history', (req, res) => {
  db.all(
    `SELECT * FROM call_history ORDER BY createdAt DESC`,
    [],
    (err, rows) => {
      res.json({
        success: true,
        history: rows,
      });
    }
  );
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});