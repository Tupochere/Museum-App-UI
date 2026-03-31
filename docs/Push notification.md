To get your FCM + Supabase flow running, you need to set up the "handshake" between the two systems. Here is the SQL to set up your database and the logic for your Cloud Function.
1. Supabase: The device_tokens Table
Run this in your Supabase SQL Editor. This table stores the unique FCM token for every device your users log into.
sql
-- Table to store FCM tokens linked to users
create table public.device_tokens (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  fcm_token text not null unique,
  device_type text, -- 'ios' or 'android'
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS (Row Level Security)
alter table public.device_tokens enable row level security;

-- Policy: Users can only insert/update/delete their own tokens
create policy "Users can manage their own tokens" 
on public.device_tokens for all 
using (auth.uid() = user_id);
Use code with caution.

2. The Cloud Function (Node.js)
This is the code Claude Code will help you deploy. It listens for a POST request from Supabase and sends the push.
File: index.js
javascript
const admin = require('firebase-admin');
const { onRequest } = require("firebase-functions/v2/https");

admin.initializeApp();

exports.sendPushNotification = onRequest(async (req, res) => {
  // 1. Get data from Supabase Webhook payload
  const { record } = req.body; 
  const recipientId = record.user_id;
  const title = record.title || "New Notification";
  const body = record.content || "You have a new message!";

  try {
    // 2. Fetch the user's FCM tokens from your Supabase table
    // (Note: You'll need to use a service role key or internal fetching logic here)
    // For this example, we assume you passed the token in the payload or fetched it
    const tokens = [/* Array of tokens fetched from your DB */];

    const message = {
      notification: { title, body },
      tokens: tokens,
    };

    // 3. Send via FCM
    const response = await admin.messaging().sendEachForMulticast(message);
    
    res.status(200).send({ success: true, responses: response.responses });
  } catch (error) {
    console.error("Error sending message:", error);
    res.status(500).send(error);
  }
});
Use code with caution.

3. The Supabase Webhook Trigger
In the Supabase Dashboard:
Go to Database > Webhooks.
Create a new Webhook named send_fcm.
Table: notifications (or whichever table holds your app alerts).
Events: INSERT.
Webhook URL: Paste the URL provided by GCP/Firebase after you deploy your Cloud Function.