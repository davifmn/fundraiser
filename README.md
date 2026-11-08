# fundraiser

Donation campaigns in **Rails 8**: a two-step donation form with **Hotwire** (Stimulus),
**Stripe Checkout** with signed, idempotent webhooks, totals that update live on every
open page (**Turbo Streams** over Action Cable), receipts by email (**Solid Queue**), and
an organizer dashboard computed by **PostgreSQL** aggregates with no N+1 queries.
Tested with **Minitest**, including system tests in headless Chrome.

Ruby 3.4 · Rails 8.1 · PostgreSQL · Hotwire (Turbo, Stimulus) · Importmap/Propshaft · Solid Queue/Cable · Stripe · Minitest/Capybara · Bullet · Kamal

- **A form that works without JavaScript and is better with it.**
  - With JavaScript: two steps, the gift (preset or custom amount, once or monthly), then
    the donor's details, with the same amount rule as the server.
  - Without it: one plain form.
  - Either way the server validates everything.
- **Money is integer cents.** `"25.50"` is parsed exactly. `"1e3"`, `"10,50"` and
  `"0.001"` are refused rather than rounded. Check constraints in the database back the
  model validations: amount range, status values, and "paid ⇔ has a payment date".
- **Payments are counted exactly once.**
  - Stripe delivers webhooks at least once. Each event id is recorded under a unique
    index, in the same transaction as its effect. A resent event is acknowledged and
    ignored; an event that fails is not recorded, so Stripe's retry processes it.
  - A second event for the same payment (`completed`, then `async_payment_succeeded`)
    finds the donation already paid, under a row lock.
  - The campaign total is incremented in SQL (`raised_cents = raised_cents + ?`), never
    read and written back from Ruby.
- **The amount is checked.** A paid amount different from the pledge raises, and the event
  is not recorded.
- **Webhook security.** The signature (HMAC of the raw body) is verified before parsing,
  and old timestamps are refused (replay protection).
- **Live.** A confirmed payment broadcasts the new total and the new supporter to every
  open campaign page, and flips the donor's own "confirming…" page to "thank you".
- **Runs without Stripe keys.** A fake gateway's checkout page produces the same events
  Stripe would, through the same processor. Set `STRIPE_SECRET_KEY` and
  `STRIPE_WEBHOOK_SECRET` to use Stripe Checkout (cards, SEPA debit, wallets;
  `mode: subscription` for monthly gifts).

```
 donor ─▶ form (Stimulus) ─▶ DonationsController#create ─▶ Donation (pending) ─▶ gateway.create_checkout
                                                                                   │ Stripe Checkout (or the fake page)
 Stripe ─▶ POST /webhooks/stripe ─▶ verify signature ─▶ WebhookProcessor ──────────┘
                                                        │ one transaction: record event id (unique)
                                                        │ + donation.mark_paid! (row lock) + campaign total (+= in SQL)
                                                        ▼ after commit
                                    Turbo Streams to open pages · receipt email via Solid Queue
```

## Quick start

```sh
bin/setup                 # installs gems, prepares the database, starts the server
bin/rails db:seed         # three campaigns with donations
```

Open http://localhost:3000 and donate: without Stripe keys you get the test checkout
page ("Pay" / "Decline"). The organizer dashboard is at `/admin` (user `admin`,
password `secret` outside production; set `ADMIN_USER` / `ADMIN_PASSWORD`).

With Stripe in test mode:

```sh
STRIPE_SECRET_KEY=sk_test_... STRIPE_WEBHOOK_SECRET=whsec_... bin/dev
stripe listen --forward-to localhost:3000/webhooks/stripe   # prints the webhook secret
```

## Tests

```sh
bin/rails test            # models, controllers, webhooks, mailer, dashboard (39 tests)
bin/rails test:system     # the donation journey in headless Chrome (4 tests)
bin/rubocop && bin/brakeman && bin/bundler-audit && bin/importmap audit
```

| Area | What is checked |
|---|---|
| Money | exact parsing, the €1–€10,000 range, database check constraints (`paid` without `paid_at` is refused by PostgreSQL) |
| Webhooks | signature required and verified; old timestamps refused; a paid session marks the donation paid and adds it to the campaign once; a resent event and a second event for the same payment change nothing; expired sessions fail the donation; an amount mismatch raises and the event is not recorded; unrelated events are ignored |
| Concurrency | two stale copies of a campaign both add their payment: the SQL increment keeps both |
| Dashboard | totals from paid donations only, top donors without anonymous gifts, daily totals; **the number of SQL queries is the same with 3 or 18 donations**; Bullet fails any test on an N+1 or unused eager load |
| Stripe adapter | the Checkout Session parameters: payment vs subscription mode, exact amount, idempotency key (without calling Stripe) |
| System | choose an amount, give details, pay, see the thank-you page and the new total; client-side amount check; a payment confirmed while the page is open appears **without a reload**; a declined payment |

CI runs all of it: the tests against PostgreSQL 18, the system tests in Chrome, RuboCop,
Brakeman, bundler-audit and the importmap audit.

## Design decisions

See [docs/decisions.md](docs/decisions.md): why Stripe Checkout and not a custom card
form, how idempotency works at each layer, why the totals are denormalized, and why the
fake gateway goes through the real webhook processor.

## Deploying

The Rails 8 defaults are kept:
- a production `Dockerfile` (with Thruster);
- `config/deploy.yml` for Kamal;
- Solid Queue, Solid Cache and Solid Cable on PostgreSQL, so no Redis is needed.

Set `RAILS_MASTER_KEY`, `DATABASE_URL`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
`ADMIN_PASSWORD` and `MAIL_FROM`.

## License

MIT
