ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    # Bullet raises on an N+1 query or an unused eager load in any test.
    setup { Bullet.start_request if Bullet.enable? }
    teardown do
      if Bullet.enable?
        Bullet.perform_out_of_channel_notifications if Bullet.notification?
        Bullet.end_request
      end
    end
  end
end

module WebhookHelper
  # Posts an event signed the way Stripe signs it (HMAC-SHA256 of "timestamp.payload").
  def post_stripe_event(event, secret: Payments.webhook_secret, at: Time.now)
    payload = event.to_json
    signature = Stripe::Webhook::Signature.compute_signature(at, payload, secret)
    header = Stripe::Webhook::Signature.generate_header(at, signature)
    post stripe_webhook_path, params: payload, headers: { "Stripe-Signature" => header, "Content-Type" => "application/json" }
  end

  def completed_event(donation, id: "evt_#{SecureRandom.hex(6)}", amount: donation.amount_cents)
    {
      "id" => id,
      "type" => "checkout.session.completed",
      "data" => { "object" => {
        "id" => donation.checkout_session_id, "object" => "checkout.session", "payment_status" => "paid",
        "payment_intent" => "pi_123", "amount_total" => amount, "currency" => "eur"
      } }
    }
  end
end
