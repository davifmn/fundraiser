module Payments
  # Applies a (verified) Stripe event. Stripe delivers webhooks at least once and may
  # resend an event, so each event id is recorded first; a repeat is acknowledged and
  # ignored. The record and its effect commit together: if processing fails, the event is
  # not recorded, the endpoint answers 500, and Stripe's retry processes it again.
  class WebhookProcessor
    Result = Data.define(:outcome, :donation)

    def process(event)
      ActiveRecord::Base.transaction do
        record = WebhookEvent.record(provider: "stripe", event_id: event.fetch("id"), event_type: event.fetch("type"), payload: event)
        return Result.new(outcome: "duplicate", donation: nil) unless record

        result = apply(event)
        record.update!(outcome: result.outcome)
        result
      end
    end

    private

    def apply(event)
      session = event.dig("data", "object") || {}
      donation = Donation.find_by(checkout_session_id: session["id"]) if session["object"] == "checkout.session"
      return Result.new(outcome: "ignored", donation: nil) unless donation

      case event["type"]
      when "checkout.session.completed", "checkout.session.async_payment_succeeded"
        return Result.new(outcome: "awaiting_payment", donation: donation) unless session["payment_status"] == "paid"

        check_amount!(donation, session)
        changed = donation.mark_paid!(payment_reference: session["payment_intent"] || session["subscription"])
        Result.new(outcome: changed ? "paid" : "already_settled", donation: donation)
      when "checkout.session.async_payment_failed", "checkout.session.expired"
        changed = donation.mark_failed!
        Result.new(outcome: changed ? "failed" : "already_settled", donation: donation)
      else
        Result.new(outcome: "ignored", donation: donation)
      end
    end

    # The amount paid must be the amount pledged. A mismatch is a bug or tampering: fail
    # loudly (the event is not recorded, so it can be retried once fixed).
    def check_amount!(donation, session)
      return if session["amount_total"].nil? || session["amount_total"] == donation.amount_cents

      raise ArgumentError, "donation #{donation.public_token}: paid #{session["amount_total"]}, pledged #{donation.amount_cents}"
    end
  end
end
