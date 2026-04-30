require('dotenv').config();

const express = require('express');
const cors = require('cors');
const twilio = require('twilio');
const Stripe = require('stripe');
const fs = require('fs');
const path = require('path');

const app = express();

console.log('PAYMENTS SERVER LOADED - STRIPE CHECKOUT ENABLED');

const stripe = Stripe(process.env.STRIPE_SECRET_KEY);

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
  topUpHistory: [],
  processedPayments: [],
};

function loadData() {
  if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify(defaultData, null, 2));
    return { ...defaultData };
  }

  const raw = fs.readFileSync(DATA_FILE, 'utf8');
  const parsed = JSON.parse(raw);

  return {
    wallet: parsed.wallet || defaultData.wallet,
    callHistory: parsed.callHistory || [],
    topUpHistory: parsed.topUpHistory || [],
    processedPayments: parsed.processedPayments || [],
  };
}

function saveData(data) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
}

function creditWalletFromSession(session) {
  const paymentId = session.payment_intent || session.id;
  const amount = Number(session.metadata?.amount || 0);

  if (amount <= 0) return;

  const data = loadData();

  if (!data.processedPayments.includes(paymentId)) {
    data.wallet.balance += amount;

    data.topUpHistory.unshift({
      paymentId,
      amount: amount.toFixed(2),
      currency: 'GBP',
      status: 'completed',
      createdAt: new Date().toISOString(),
    });

    data.processedPayments.push(paymentId);
    saveData(data);

    console.log(`Wallet credited: £${amount.toFixed(2)}`);
  }
}

// Stripe webhook needs raw body before express.json()
app.post('/stripe-webhook', express.raw({ type: 'application/json' }), (req, res) => {
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  let event;

  try {
    if (webhookSecret) {
      const signature = req.headers['stripe-signature'];
      event = stripe.webhooks.constructEvent(req.body, signature, webhookSecret);
    } else {
      event = JSON.parse(req.body.toString());
    }
  } catch (err) {
    console.error('Stripe webhook error:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === 'checkout.session.completed') {
    creditWalletFromSession(event.data.object);
  }

  res.sendStatus(200);
});

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

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

app.post('/create-checkout-session', async (req, res) => {
  try {
    const amount = Number(req.body.amount);
    const allowedAmounts = [5, 10, 20];

    if (!allowedAmounts.includes(amount)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid top-up amount',
      });
    }

    const baseUrl = process.env.BASE_URL || 'https://callnaija-backend.onrender.com';

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      success_url: `${baseUrl}/payment-success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${baseUrl}/payment-cancelled`,
      line_items: [
        {
          price_data: {
            currency: 'gbp',
            product_data: {
              name: `CallNaija Wallet Top Up £${amount}`,
            },
            unit_amount: amount * 100,
          },
          quantity: 1,
        },
      ],
      metadata: {
        amount: amount.toString(),
      },
    });

    res.json({
      success: true,
      checkoutUrl: session.url,
    });
  } catch (err) {
    console.error('Stripe checkout error:', err.message);

    res.status(500).json({
      success: false,
      error: err.message,
    });
  }
});

app.get('/payment-success', async (req, res) => {
  try {
    const sessionId = req.query.session_id;

    if (!sessionId) {
      return res.send(`
        <h2>Payment successful</h2>
        <p>Missing session ID. Please return to the app and refresh wallet.</p>
      `);
    }

    const session = await stripe.checkout.sessions.retrieve(sessionId);

    if (session.payment_status === 'paid') {
      creditWalletFromSession(session);
    }

    res.send(`
      <h2>Payment successful</h2>
      <p>Your CallNaija wallet has been updated. You can now return to the app.</p>
    `);
  } catch (err) {
    console.error('Payment success error:', err.message);

    res.send(`
      <h2>Payment received</h2>
      <p>We could not update the wallet immediately. Please return to the app and refresh.</p>
    `);
  }
});

app.get('/payment-success', (req, res) => {
  res.send(`
    <html>
      <head>
        <title>Payment Successful</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: Arial, sans-serif;
            text-align: center;
            padding: 40px;
            background: #f6fbf7;
          }
          h2 {
            color: #0A7C3A;
          }
          p {
            color: #444;
            margin-top: 10px;
          }
        </style>
      </head>
      <body>
        <h2>Payment successful 🎉</h2>
        <p>Your wallet has been updated.</p>
        <p>You can now return to the app.</p>

        <script>
          setTimeout(() => {
            window.close();
          }, 3000);
        </script>
      </body>
    </html>
  `);
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

  const data = loadData();
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