module Payments
  # Stands in for Stripe when there are no API keys. Its checkout page (FakeCheckoutsController)
  # turns "pay" and "decline" into the events Stripe would send.
  class FakeGateway
    include Rails.application.routes.url_helpers

    def create_checkout(donation, success_url:, cancel_url:)
      Checkout.new(session_id: "cs_fake_#{donation.public_token}", url: fake_checkout_path(donation))
    end

    # A Stripe-shaped event for a session of this gateway.
    def self.event(donation, type, payment_status: nil)
      {
        "id" => "evt_fake_#{SecureRandom.hex(12)}",
        "type" => type,
        "data" => {
          "object" => {
            "id" => donation.checkout_session_id,
            "object" => "checkout.session",
            "payment_status" => payment_status,
            "payment_intent" => "pi_fake_#{donation.public_token}",
            "amount_total" => donation.amount_cents,
            "currency" => donation.currency.downcase
          }
        }
      }
    end
  end
end
