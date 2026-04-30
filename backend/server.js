require('dotenv').config();

const express = require('express');
const cors = require('cors');
const twilio = require('twilio');
const Stripe = require('stripe');
const bcrypt = require('bcryptjs');
const fs = require('fs');
const path = require('path');

const http = require('http');
const { Server } = require('socket.io'); 

const app = express();

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

const onlineUsers = {};

console.log('CALLNAIJA SERVER LOADED - OTP ENABLED');

const stripe = Stripe(process.env.STRIPE_SECRET_KEY);

const client = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

const VERIFY_SERVICE_SID = process.env.TWILIO_VERIFY_SERVICE_SID;

const DATA_FILE = path.join(__dirname, 'data.json');

const defaultData = {
  users: [],
  processedPayments: [],
};

function loadData() {
  if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify(defaultData, null, 2));
    return JSON.parse(JSON.stringify(defaultData));
  }

  const raw = fs.readFileSync(DATA_FILE, 'utf8');
  const parsed = JSON.parse(raw);

  return {
    users: parsed.users || [],
    processedPayments: parsed.processedPayments || [],
  };
}

function saveData(data) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
}

function cleanPhone(phone) {
  return String(phone || '').replace(/\s/g, '').trim();
}

function publicUser(user) {
  return {
    id: user.id,
    name: user.name,
    phone: user.phone,
    isVerified: user.isVerified === true,
    wallet: user.wallet,
  };
}

function findUserByPhone(data, phone) {
  const cleaned = cleanPhone(phone);
  return data.users.find((user) => user.phone === cleaned);
}

function requireUser(req, res) {
  const phone = cleanPhone(req.headers['x-user-phone'] || req.query.phone);

  if (!phone) {
    res.status(401).json({
      success: false,
      error: 'User phone required',
    });
    return null;
  }

  const data = loadData();
  const user = findUserByPhone(data, phone);

  if (!user) {
    res.status(401).json({
      success: false,
      error: 'User not found',
    });
    return null;
  }

  if (user.isVerified !== true) {
    res.status(403).json({
      success: false,
      error: 'Phone number not verified',
    });
    return null;
  }

  return { data, user };
}

async function sendOtpToPhone(phone) {
  if (!VERIFY_SERVICE_SID) {
    throw new Error('TWILIO_VERIFY_SERVICE_SID is missing');
  }

  return client.verify.v2
    .services(VERIFY_SERVICE_SID)
    .verifications.create({
      to: phone,
      channel: 'sms',
    });
}

async function checkOtpCode(phone, code) {
  if (!VERIFY_SERVICE_SID) {
    throw new Error('TWILIO_VERIFY_SERVICE_SID is missing');
  }

  return client.verify.v2
    .services(VERIFY_SERVICE_SID)
    .verificationChecks.create({
      to: phone,
      code,
    });
}

function creditWalletFromSession(session) {
  const paymentId = session.payment_intent || session.id;
  const amount = Number(session.metadata?.amount || 0);
  const phone = cleanPhone(session.metadata?.phone);

  if (amount <= 0 || !phone) return;

  const data = loadData();
  const user = findUserByPhone(data, phone);

  if (!user) {
    console.log('Payment received but user not found:', phone);
    return;
  }

  if (data.processedPayments.includes(paymentId)) {
    console.log('Payment already processed:', paymentId);
    return;
  }

  user.wallet.balance += amount;

  user.topUpHistory.unshift({
    paymentId,
    amount: amount.toFixed(2),
    currency: 'GBP',
    status: 'completed',
    createdAt: new Date().toISOString(),
  });

  data.processedPayments.push(paymentId);
  saveData(data);

  console.log(`Wallet credited for ${phone}: £${amount.toFixed(2)}`);
}

app.post(
  '/stripe-webhook',
  express.raw({ type: 'application/json' }),
  (req, res) => {
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
    let event;

    try {
      if (webhookSecret) {
        const signature = req.headers['stripe-signature'];
        event = stripe.webhooks.constructEvent(
          req.body,
          signature,
          webhookSecret
        );
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
  }
);

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

const callStatuses = {};
const RATE_PER_MINUTE = 0.10;
const MINIMUM_BALANCE_TO_CALL = 0.20;

app.get('/', (req, res) => {
  res.send('CallNaija API is running');
});

app.post('/register', async (req, res) => {
  try {
    const name = String(req.body.name || '').trim();
    const phone = cleanPhone(req.body.phone);
    const password = String(req.body.password || '');

    if (!name || !phone || !password) {
      return res.status(400).json({
        success: false,
        error: 'Name, phone and password are required',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        error: 'Password must be at least 6 characters',
      });
    }

    const data = loadData();

    if (findUserByPhone(data, phone)) {
      return res.status(409).json({
        success: false,
        error: 'Account already exists. Please login.',
      });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = {
      id: `user_${Date.now()}`,
      name,
      phone,
      passwordHash,
      isVerified: false,
      wallet: {
        balance: 0.0,
        currency: 'GBP',
      },
      callHistory: [],
      topUpHistory: [],
      createdAt: new Date().toISOString(),
    };

    data.users.push(user);
    saveData(data);

    await sendOtpToPhone(phone);

    res.json({
      success: true,
      message: 'Account created. Verification code sent.',
      requiresVerification: true,
      user: publicUser(user),
    });
  } catch (err) {
    console.error('Register error:', err.message);

    res.status(500).json({
      success: false,
      error: err.message || 'Could not create account',
    });
  }
});

app.post('/send-otp', async (req, res) => {
  try {
    const phone = cleanPhone(req.body.phone);

    if (!phone) {
      return res.status(400).json({
        success: false,
        error: 'Phone number is required',
      });
    }

    const data = loadData();
    const user = findUserByPhone(data, phone);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Account not found',
      });
    }

    await sendOtpToPhone(phone);

    res.json({
      success: true,
      message: 'Verification code sent',
    });
  } catch (err) {
    console.error('Send OTP error:', err.message);

    res.status(500).json({
      success: false,
      error: err.message || 'Could not send verification code',
    });
  }
});

app.post('/verify-otp', async (req, res) => {
  try {
    const phone = cleanPhone(req.body.phone);
    const code = String(req.body.code || '').trim();

    if (!phone || !code) {
      return res.status(400).json({
        success: false,
        error: 'Phone and code are required',
      });
    }

    const check = await checkOtpCode(phone, code);

    if (check.status !== 'approved') {
      return res.status(400).json({
        success: false,
        error: 'Invalid verification code',
      });
    }

    const data = loadData();
    const user = findUserByPhone(data, phone);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Account not found',
      });
    }

    user.isVerified = true;
    user.verifiedAt = new Date().toISOString();

    saveData(data);

    res.json({
      success: true,
      message: 'Phone verified',
      user: publicUser(user),
    });
  } catch (err) {
    console.error('Verify OTP error:', err.message);

    res.status(500).json({
      success: false,
      error: err.message || 'Could not verify code',
    });
  }
});

app.post('/login', async (req, res) => {
  try {
    const phone = cleanPhone(req.body.phone);
    const password = String(req.body.password || '');

    if (!phone || !password) {
      return res.status(400).json({
        success: false,
        error: 'Phone and password are required',
      });
    }

    const data = loadData();
    const user = findUserByPhone(data, phone);

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid phone or password',
      });
    }

    const passwordOk = await bcrypt.compare(password, user.passwordHash);

    if (!passwordOk) {
      return res.status(401).json({
        success: false,
        error: 'Invalid phone or password',
      });
    }

    if (user.isVerified !== true) {
      await sendOtpToPhone(phone);

      return res.status(403).json({
        success: false,
        requiresVerification: true,
        phone,
        error: 'Phone number not verified. Verification code sent.',
      });
    }

    res.json({
      success: true,
      message: 'Login successful',
      user: publicUser(user),
    });
  } catch (err) {
    console.error('Login error:', err.message);

    res.status(500).json({
      success: false,
      error: err.message || 'Could not login',
    });
  }
});

app.get('/wallet', (req, res) => {
  const result = requireUser(req, res);
  if (!result) return;

  const { user } = result;

  res.json({
    success: true,
    balance: user.wallet.balance.toFixed(2),
    currency: user.wallet.currency,
    ratePerMinute: RATE_PER_MINUTE.toFixed(2),
  });
});

app.post('/create-checkout-session', async (req, res) => {
  try {
    const amount = Number(req.body.amount);
    const phone = cleanPhone(req.body.phone);

    const allowedAmounts = [5, 10, 20];

    if (!allowedAmounts.includes(amount)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid top-up amount',
      });
    }

    const data = loadData();
    const user = findUserByPhone(data, phone);

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'User not found',
      });
    }

    if (user.isVerified !== true) {
      return res.status(403).json({
        success: false,
        error: 'Phone number not verified',
      });
    }

    const baseUrl =
      process.env.BASE_URL || 'https://callnaija-backend.onrender.com';

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
        phone,
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

    if (sessionId) {
      const session = await stripe.checkout.sessions.retrieve(sessionId);

      if (session.payment_status === 'paid') {
        creditWalletFromSession(session);
      }
    }

    res.send(`
      <html>
        <head>
          <title>Payment Successful</title>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 40px; background: #f6fbf7; }
            .card { max-width: 420px; margin: 0 auto; background: white; border-radius: 24px; padding: 32px 24px; box-shadow: 0 12px 30px rgba(0,0,0,0.08); }
            .icon { width: 72px; height: 72px; border-radius: 50%; background: #0A7C3A; color: white; display: flex; align-items: center; justify-content: center; margin: 0 auto 18px; font-size: 36px; }
            h2 { color: #0A7C3A; margin-bottom: 10px; }
            p { color: #444; line-height: 1.5; }
            .small { font-size: 13px; color: #777; margin-top: 18px; }
            button { margin-top: 18px; background: #0A7C3A; color: white; border: none; padding: 14px 22px; border-radius: 999px; font-weight: bold; font-size: 15px; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="icon">✓</div>
            <h2>Payment successful</h2>
            <p>Your CallNaija wallet has been updated.</p>
            <p>You can now return to the app.</p>
            <button onclick="window.close()">Close this page</button>
            <p class="small">If this page does not close automatically, go back to CallNaija.</p>
          </div>
          <script>
            setTimeout(() => { window.close(); }, 3000);
          </script>
        </body>
      </html>
    `);
  } catch (err) {
    console.error('Payment success error:', err.message);

    res.send(`
      <html>
        <head>
          <title>Payment Received</title>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: Arial; text-align: center; padding: 40px;">
          <h2>Payment received</h2>
          <p>Please return to the app and refresh your wallet.</p>
        </body>
      </html>
    `);
  }
});

app.get('/payment-cancelled', (req, res) => {
  res.send(`
    <html>
      <head>
        <title>Payment Cancelled</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
      </head>
      <body style="font-family: Arial; text-align: center; padding: 40px; background: #f6fbf7;">
        <h2>Payment cancelled</h2>
        <p>No money was taken. You can return to CallNaija.</p>
      </body>
    </html>
  `);
});

app.post('/call', async (req, res) => {
  const { callerNumber, receiverNumber, phone } = req.body;

  if (!callerNumber || !receiverNumber || !phone) {
    return res.status(400).json({
      success: false,
      error: 'User phone, caller number and receiver number are required',
    });
  }

  const data = loadData();
  const user = findUserByPhone(data, phone);

  if (!user) {
    return res.status(401).json({
      success: false,
      error: 'User not found',
    });
  }

  if (user.isVerified !== true) {
    return res.status(403).json({
      success: false,
      error: 'Phone number not verified',
    });
  }

  if (user.wallet.balance < MINIMUM_BALANCE_TO_CALL) {
    return res.status(402).json({
      success: false,
      error: 'Insufficient balance',
      balance: user.wallet.balance.toFixed(2),
    });
  }

  try {
    const cleanCaller = cleanPhone(callerNumber);
    const cleanReceiver = cleanPhone(receiverNumber);

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
          <Dial callerId="${process.env.TWILIO_PHONE_NUMBER}" timeout="25" answerOnBridge="true">
            <Number>${cleanReceiver}</Number>
          </Dial>
          <Say voice="alice">The call could not be connected.</Say>
        </Response>
      `,
    });

    callStatuses[call.sid] = {
      callSid: call.sid,
      userPhone: user.phone,
      status: 'initiated',
      from: cleanCaller,
      to: cleanReceiver,
      duration: 0,
      cost: '0.00',
      charged: false,
      walletBalance: user.wallet.balance.toFixed(2),
    };

    res.json({
      success: true,
      message: 'Bridge call started',
      sid: call.sid,
      status: 'initiated',
      balance: user.wallet.balance.toFixed(2),
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

  const existing = callStatuses[callSid];

  if (!existing) {
    return res.sendStatus(200);
  }

  const data = loadData();
  const user = findUserByPhone(data, existing.userPhone);

  if (!user) {
    return res.sendStatus(200);
  }

  let cost = existing.cost || '0.00';
  let charged = existing.charged || false;

  if (callStatus === 'completed' && !charged) {
    const minutes = Math.max(1, Math.ceil(duration / 60));
    const callCost = minutes * RATE_PER_MINUTE;

    user.wallet.balance = Math.max(0, user.wallet.balance - callCost);

    cost = callCost.toFixed(2);
    charged = true;

    user.callHistory.unshift({
      callSid,
      from: existing.from || req.body.From || null,
      to: existing.to || req.body.To || null,
      status: callStatus,
      duration,
      cost,
      currency: user.wallet.currency,
      walletBalanceAfter: user.wallet.balance.toFixed(2),
      createdAt: new Date().toISOString(),
    });

    saveData(data);
  }

  callStatuses[callSid] = {
    ...existing,
    callSid,
    status: callStatus || 'unknown',
    duration,
    cost,
    charged,
    walletBalance: user.wallet.balance.toFixed(2),
  };

  res.sendStatus(200);
});

app.get('/call-status/:sid', (req, res) => {
  const status = callStatuses[req.params.sid];

  if (!status) {
    return res.status(404).json({
      success: false,
      status: 'unknown',
    });
  }

  const data = loadData();
  const user = findUserByPhone(data, status.userPhone);

  res.json({
    success: true,
    ...status,
    walletBalance: user ? user.wallet.balance.toFixed(2) : status.walletBalance,
  });
});

app.get('/call-history', (req, res) => {
  const result = requireUser(req, res);
  if (!result) return;

  const { user } = result;

  res.json({
    success: true,
    history: user.callHistory || [],
  });
});

const PORT = process.env.PORT || 3000;

io.on('connection', (socket) => {
  console.log('Socket connected:', socket.id);

  socket.on('user-online', ({ phone, name }) => {
    if (!phone) return;

    onlineUsers[phone] = {
      socketId: socket.id,
      phone,
      name: name || phone,
    };

    console.log('User online:', phone);
    io.emit('online-users', Object.values(onlineUsers));
  });

  socket.on('call-user', ({ fromPhone, fromName, toPhone, offer }) => {
    const target = onlineUsers[toPhone];

    if (!target) {
      socket.emit('call-error', {
        message: 'User is not online',
      });
      return;
    }

    io.to(target.socketId).emit('incoming-call', {
      fromPhone,
      fromName,
      offer,
    });
  });

  socket.on('answer-call', ({ toPhone, answer }) => {
    const target = onlineUsers[toPhone];

    if (target) {
      io.to(target.socketId).emit('call-answered', {
        answer,
      });
    }
  });

  socket.on('reject-call', ({ toPhone }) => {
    const target = onlineUsers[toPhone];

    if (target) {
      io.to(target.socketId).emit('call-rejected');
    }
  });

  socket.on('ice-candidate', ({ toPhone, candidate }) => {
    const target = onlineUsers[toPhone];

    if (target) {
      io.to(target.socketId).emit('ice-candidate', {
        candidate,
      });
    }
  });

  socket.on('end-call', ({ toPhone }) => {
    const target = onlineUsers[toPhone];

    if (target) {
      io.to(target.socketId).emit('call-ended');
    }
  });

  socket.on('disconnect', () => {
    const phone = Object.keys(onlineUsers).find(
      (key) => onlineUsers[key].socketId === socket.id
    );

    if (phone) {
      delete onlineUsers[phone];
      console.log('User offline:', phone);
      io.emit('online-users', Object.values(onlineUsers));
    }

    console.log('Socket disconnected:', socket.id);
  });
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});