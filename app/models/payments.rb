# Payment providers behind one small interface:
#
#   gateway.create_checkout(donation, success_url:, cancel_url:) → Payments::Checkout
#
# With STRIPE_SECRET_KEY set, donations go through Stripe Checkout. Without it (development,
# tests, the demo) a fake gateway stands in: its checkout page produces the same events a
# Stripe webhook would, and they go through the same WebhookProcessor.
module Payments
  Checkout = Data.define(:session_id, :url)

  def self.gateway
    stripe? ? StripeGateway.new : FakeGateway.new
  end

  def self.stripe? = ENV["STRIPE_SECRET_KEY"].present?

  def self.fake? = !stripe?

  def self.webhook_secret
    ENV.fetch("STRIPE_WEBHOOK_SECRET") { Rails.env.production? ? raise("STRIPE_WEBHOOK_SECRET is not set") : "whsec_development" }
  end
end
