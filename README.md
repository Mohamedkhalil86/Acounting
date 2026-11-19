# حسابي — Debt & Client Ledger

Arabic RTL client ledger built with Next.js App Router, TypeScript, Tailwind CSS, and Supabase Auth/Postgres. The ledger uses one client record per account and stores signed balances as positive (client owes you) and negative (you owe client).

## Local setup

1. Install Node.js 20 or newer, then install dependencies:

   ```bash
   npm install
   ```

2. Create a Supabase project. In **Project Settings → API**, copy the project URL and the public anon/publishable key into `.env.local` (use `.env.example` as a template):

   ```env
   NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
   ```

3. Apply the migrations in order. Open the Supabase **SQL Editor** and run each file in `supabase/migrations/` in filename order. They create the profile trigger, tables, indexes, RLS policies, atomic ledger RPC functions, client contact fields, and the password-confirmed client deletion RPC. In a CLI-managed project, apply them with `supabase db push` after linking the project.

4. In **Authentication → Providers → Email**, enable Email authentication. Configure the site URL and allowed redirect URLs for your local app (for example `http://localhost:3000/**`). If email confirmation is enabled, users must confirm the signup email before signing in.

5. For six-digit password recovery codes, open **Authentication → Email Templates → Reset Password** and use the OTP token in the message body, for example:

   ```text
   رمز استعادة كلمة المرور: {{ .Token }}
   ```

   The app calls `resetPasswordForEmail`, then verifies the submitted six-digit code with `verifyOtp({ type: 'recovery' })`. If you use a recovery link template instead, its verified session is also accepted and the app opens the new-password step. Set the redirect URL to `http://localhost:3000/login?recovery=1` (and the matching production URL after deployment).

6. Start the development server:

   ```bash
   npm run dev
   ```

   Visit [http://localhost:3000](http://localhost:3000). For production, configure the same environment variables in the hosting provider, then use `npm run build` and `npm start`.

## Data and security notes

- Every client and ledger transaction is scoped by `auth.uid()` and protected by RLS.
- Transaction writes go through security-definer Postgres functions that validate ownership, lock the client row, recompute every running balance in chronological order, and write an audit record in the same database transaction.
- Direct browser write privileges on transactions and audit records are revoked so balance recalculation cannot be bypassed. Client rows can be read and managed only by their owner.
- Store monetary values as decimal currency amounts; do not use floating-point arithmetic for server-side balance calculations.
