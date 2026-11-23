# TOPCLASS TRACK

Repair tracking and customer management platform for Top Class Auto Body Zimbabwe.

## Current implementation

- Next.js App Router, TypeScript, Tailwind CSS and responsive workshop dashboard.
- Searchable repair job table, job card creation, stage progression, job detail drawer/modal and sample reporting views.
- Separate admin and customer ID/password sign-ins at `/login`; the staff dashboard requires an active admin profile when Supabase is configured.
- Customer IDs map to synthetic Supabase Auth email identifiers; customer passwords are verified by Supabase Auth and customer records remain isolated by RLS.
- PostgreSQL migration with relational records, role enum, status history, audit log, private Storage buckets, indexes and row-level security policies.
- Dashboard sample data and browser-local demo job cards are only for product demonstration. They are not shared or persisted in the production database. The dashboard displays a DEMO WORKSPACE indicator.
- When Supabase variables are absent, demo-only sign-in is enabled: admin `admin@topclass.demo` / `TopClassAdmin!26`; customer `CUS-DEMO-001` / `VehicleTrack!26`. These accounts unlock only sample data stored in this browser, not actual customer records.

## Run locally

1. Install Node.js 20 or newer.
2. Copy `.env.example` to `.env.local`.
3. Install packages with `npm install`.
4. For a visual demo without backend credentials, run `npm run dev`; sample records are shown and newly created demo jobs persist only in this browser's local storage.
5. Configure Supabase for real data (below) before using customer accounts or production workflows.

## Supabase setup

1. Create a Supabase project and copy its project URL and `anon` key into `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` in `.env.local`.
2. Apply `supabase/migrations/202611230001_initial_schema.sql` with the Supabase CLI (`supabase link`, then `supabase db push`) or the SQL editor.
3. Disable public sign-up in Supabase Auth. Create admin accounts in Supabase Auth, then add a matching `profiles` row with `role='admin'` and `active=true` using a trusted admin process. The admin signs in with their email and password.
4. For each customer, create an Auth user with email `customer-<normalized-customer-id>@accounts.topclasstrack.invalid`, set a password, and mark the account email confirmed. Normalization lowercases the customer ID and removes all characters except letters and digits. For example, customer reference `CUS-12AB34CD` uses `customer-cus12ab34cd@accounts.topclasstrack.invalid`.
5. Copy that Auth user UUID into `customers.auth_user_id`. Customer accounts must also have a `profiles` row with `role='customer'`, `active=true`, and `customer_id` set to the matching customer UUID. Customers sign in using their visible customer reference and the password set by the administrator; they do not enter the synthetic email.
6. Do not expose the service role key in browser code. Keep account provisioning in the trusted Supabase dashboard or a protected server-side admin process. The app does not provide public account registration or password reset yet; administrators provision and reset accounts.
7. `RESEND_API_KEY` and WhatsApp variables are reserved for future notification delivery; no delivery is reported unless an actual provider is configured and called. Set `NEXT_PUBLIC_APP_URL` to the deployed origin and review the RLS policies before production launch.

## Environment variables

See `.env.example`. `SUPABASE_SERVICE_ROLE_KEY` is server-only and must never be prefixed with `NEXT_PUBLIC_`. The current client uses only the public anon key and database RLS. Supabase Storage buckets are private.

## Customer access and security

Customers use customer ID plus password through Supabase Auth. The ID alone cannot sign in. RLS ties customer reads to the authenticated user's `auth_user_id`; customer photo and document reads are filtered by visibility. Internal notes are excluded from the customer portal query. The staff dashboard requires an active admin profile. No public signup is included. Administrators provision accounts through a trusted Supabase dashboard or server-side process, never from a public browser form.

## Notifications and uploads

The schema records in-app/email/WhatsApp channel status and errors, but provider delivery is not implemented in this first slice. No WhatsApp or email delivery is simulated. The demo upload control explains that storage must be configured; production upload UI and signed document retrieval remain to be connected to the private buckets.

## Build

```sh
npm install
npm run dev
npm run build
npm start
```

The demo sign-in is only a walkthrough account and must never be used for real records. Set both Supabase public variables in the production deployment; when configured, demo credentials are disabled and actual Supabase authentication plus the admin profile check are used. The demo is suitable for a product walkthrough; complete the production workflows for database-backed staff screens, upload handling, quotation decisions, notification delivery, and operational reporting before deploying it for live customer data.
