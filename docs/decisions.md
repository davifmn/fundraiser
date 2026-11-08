# Design decisions

## 1. Stripe Checkout, not a custom card form

Stripe hosts the payment page, so card data never reaches this application. That keeps
it out of the scope of PCI DSS beyond the simplest questionnaire (SAQ A). It also brings
SEPA debit, wallets and 3-D Secure (Strong Customer Authentication, mandatory in the EU)
without code here.

The cost is a redirect, and the payment result arrives **asynchronously** by webhook. So
the donor's page says "confirming…" and updates itself when the webhook lands (Turbo
Stream). The success URL is never taken as proof of payment.

## 2. Idempotency at every layer

A payment must be counted once, whatever is retried.

| Layer | Duplicate it guards against | How |
|---|---|---|
| Creating the checkout | a retried request (timeout, double click) creating two sessions | Stripe idempotency key `checkout-<donation token>` |
| Receiving an event | Stripe resending the same event (at-least-once delivery) | `webhook_events (provider, event_id)` unique index; `INSERT … ON CONFLICT DO NOTHING` |
| Applying a payment | two different events for the same payment (`completed`, then `async_payment_succeeded`) | `Donation#mark_paid!` takes a row lock and only acts on a pending donation |
| Updating the total | two payments at the same time | `UPDATE campaigns SET raised_cents = raised_cents + ?`, a single statement |

The event record and its effect are **one transaction**. If processing raises (an amount
mismatch, the database going away), the event is not recorded. The endpoint answers
500, and Stripe retries later.

## 3. Denormalized totals

`campaigns.raised_cents` and `donations_count` are updated with each payment, in SQL, in
the payment's transaction. The campaign page, the most visited page, then reads one row
instead of summing the donations table, and Turbo can broadcast the new total
immediately.

The organizer dashboard computes everything again from the donations with `GROUP BY`. It
is the place where a drift between the two would show.

## 4. The fake gateway goes through the real processor

Without Stripe keys, the checkout page is local. Its "Pay" button builds the same event
Stripe would send and hands it to `Payments::WebhookProcessor`, the same code as the real
webhook. Development, demos and system tests therefore exercise the real payment logic
(idempotency, row lock, totals, broadcasts, receipt), and only the HTTP signature check
is skipped. The webhook controller tests cover that check with genuinely signed payloads.

## 5. No N+1 by construction, and proven

The dashboard is four queries:
- per-campaign aggregates with `FILTER (WHERE …)`;
- top donors;
- daily totals;
- the latest donations, with their campaigns preloaded.

A test counts the SQL queries of the page with 3 and with 18 donations and requires the
same number. Bullet is on in the test environment and fails any test that triggers an
N+1 query or an unused eager load. It caught one during development: an `includes` that
a page did not need.

## 6. Progressive enhancement

The donation form is a normal Rails form. The Stimulus controller adds the two steps,
the preset buttons and the live summary ("You give €25.00 every month."). It validates
the amount with the same rule as `Donation#amount=`, so the client and the server never
disagree on what is valid.
