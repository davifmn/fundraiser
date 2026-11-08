module Payments
  # Stripe Checkout: Stripe hosts the payment page (cards, SEPA debit, wallets), so card
  # data never touches this application. One-time gifts are a "payment" session, monthly
  # gifts a "subscription" session.
  class StripeGateway
    def initialize(api_key: ENV.fetch("STRIPE_SECRET_KEY"), sessions: Stripe::Checkout::Session)
      @api_key = api_key
      @sessions = sessions
    end

    def create_checkout(donation, success_url:, cancel_url:)
      price_data = {
        currency: donation.currency.downcase,
        unit_amount: donation.amount_cents,
        product_data: { name: "Donation to #{donation.campaign.title}" }
      }
      price_data[:recurring] = { interval: "month" } if donation.monthly?

      session = @sessions.create(
        {
          mode: donation.monthly? ? "subscription" : "payment",
          line_items: [ { price_data: price_data, quantity: 1 } ],
          customer_email: donation.donor_email,
          client_reference_id: donation.public_token,
          metadata: { donation: donation.public_token, campaign: donation.campaign.slug },
          success_url: success_url,
          cancel_url: cancel_url
        },
        # Retrying the request (a timeout, a double click) returns the same session
        # instead of creating a second one.
        { api_key: @api_key, idempotency_key: "checkout-#{donation.public_token}" }
      )
      Checkout.new(session_id: session.id, url: session.url)
    end
  end
end
