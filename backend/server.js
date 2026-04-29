require('dotenv').config();

const express = require('express');
const cors = require('cors');
const twilio = require('twilio');
const fs = require('fs');
const path = require('path');

const app = express();

console.log('BATCH 16 SERVER LOADED - JSON STORAGE ENABLED');

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

const client = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

const DATA_FILE = path.join(__dirname, 'data.json');

const defaultData = {
  wallet: {
    balance: 5.0,
    currency: 'GBP',
  },
  callHistory: [],
};

function loadData() {
  if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify(defaultData, null, 2));
    return defaultData;
  }

  const raw = fs.readFileSync(DATA_FILE, 'utf8');
  return JSON.parse(raw);
}

function saveData(data) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
}

const callStatuses = {};
const RATE_PER_MINUTE = 0.10;
const MINIMUM_BALANCE_TO_CALL = 0.20;

app.get('/', (req, res) => {
  res.send('CallNaija API is running');
});

app.get('/wallet', (req, res) => {
  const data = loadData();

  res.json({
    success: true,
    balance: data.wallet.balance.toFixed(2),
    currency: data.wallet.currency,
    ratePerMinute: RATE_PER_MINUTE.toFixed(2),
  });
});

app.post('/wallet/top-up', (req, res) => {
  const amount = Number(req.body.amount);

  if (!amount || amount <= 0) {
    return res.status(400).json({
      success: false,
      error: 'Invalid amount',
    });
  }

  const data = loadData();
  data.wallet.balance += amount;
  saveData(data);

  res.json({
    success: true,
    balance: data.wallet.balance.toFixed(2),
    currency: data.wallet.currency,
  });
});

app.post('/call', async (req, res) => {
  const { callerNumber, receiverNumber } = req.body;

  if (!callerNumber || !receiverNumber) {
    return res.status(400).json({
      success: false,
      error: 'Numbers required',
    });
  }

  const data = loadData();

  if (data.wallet.balance < MINIMUM_BALANCE_TO_CALL) {
    return res.status(402).json({
      success: false,
      error: 'Insufficient balance',
      balance: data.wallet.balance.toFixed(2),
    });
  }

  try {
    const cleanCaller = callerNumber.replace(/\s/g, '');
    const cleanReceiver = receiverNumber.replace(/\s/g, '');

    const call = await client.calls.create({
      to: cleanCaller,
      from: process.env.TWILIO_PHONE_NUMBER,
      timeout: 25,
      statusCallback: `${process.env.BASE_URL}/status`,
      statusCallbackEvent: ['initiated', 'ringing', 'answered', 'completed'],
      statusCallbackMethod: 'POST',
      twiml: `
        <Response>
          <Say voice="alice">CallNaija is connecting your call. Please wait.</Say>
          <Dial 
            callerId="${process.env.TWILIO_PHONE_NUMBER}" 
            timeout="25"
            answerOnBridge="true"
          >
            <Number>${cleanReceiver}</Number>
          </Dial>
          <Say voice="alice">The call could not be connected.</Say>
        </Response>
      `,
    });

    callStatuses[call.sid] = {
      callSid: call.sid,
      status: 'initiated',
      from: cleanCaller,
      to: cleanReceiver,
      duration: 0,
      cost: '0.00',
      charged: false,
      walletBalance: data.wallet.balance.toFixed(2),
    };

    res.json({
      success: true,
      message: 'Bridge call started',
      sid: call.sid,
      status: 'initiated',
      balance: data.wallet.balance.toFixed(2),
    });
  } catch (err) {
    console.error('Twilio error:', err.message);

    res.status(500).json({
      success: false,
      error: err.message,
    });
  }
});

app.post('/status', (req, res) => {
  const callSid = req.body.CallSid;
  const callStatus = req.body.CallStatus;
  const duration = Number(req.body.CallDuration || 0);

  console.log('--- Twilio Call Status Update ---');
  console.log('Call SID:', callSid);
  console.log('Status:', callStatus);
  console.log('Duration:', duration);
  console.log('--------------------------------');

  if (!callSid) {
    return res.sendStatus(200);
  }

  const existing = callStatuses[callSid] || {
    callSid,
    status: callStatus || 'unknown',
    from: req.body.From || null,
    to: req.body.To || null,
    duration: 0,
    cost: '0.00',
    charged: false,
  };

  let data = loadData();
  let cost = existing.cost || '0.00';
  let charged = existing.charged || false;

  if (callStatus === 'completed' && !charged) {
    const minutes = Math.max(1, Math.ceil(duration / 60));
    const callCost = minutes * RATE_PER_MINUTE;

    data.wallet.balance = Math.max(0, data.wallet.balance - callCost);

    cost = callCost.toFixed(2);
    charged = true;

    data.callHistory.unshift({
      callSid,
      from: existing.from || req.body.From || null,
      to: existing.to || req.body.To || null,
      status: callStatus,
      duration,
      cost,
      currency: data.wallet.currency,
      walletBalanceAfter: data.wallet.balance.toFixed(2),
      createdAt: new Date().toISOString(),
    });

    saveData(data);

    console.log(`Charged £${cost}. New balance: £${data.wallet.balance.toFixed(2)}`);
  }

  callStatuses[callSid] = {
    ...existing,
    callSid,
    status: callStatus || 'unknown',
    from: existing.from || req.body.From || null,
    to: existing.to || req.body.To || null,
    duration,
    cost,
    charged,
    walletBalance: data.wallet.balance.toFixed(2),
  };

  res.sendStatus(200);
});

app.get('/call-status/:sid', (req, res) => {
  const data = loadData();
  const status = callStatuses[req.params.sid];

  if (!status) {
    return res.status(404).json({
      success: false,
      status: 'unknown',
    });
  }

  res.json({
    success: true,
    ...status,
    walletBalance: data.wallet.balance.toFixed(2),
  });
});

app.get('/call-history', (req, res) => {
  const data = loadData();

  res.json({
    success: true,
    history: data.callHistory,
  });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});