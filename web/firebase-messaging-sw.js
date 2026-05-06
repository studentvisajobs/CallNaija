importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "YOUR_WEB_API_KEY",
  authDomain: "callnaija.firebaseapp.com",
  projectId: "callnaija",
  storageBucket: "callnaija.firebasestorage.app",
  messagingSenderId: "324328357412",
  appId: "YOUR_WEB_APP_ID"
});

firebase.messaging();