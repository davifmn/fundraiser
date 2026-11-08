require "test_helper"

class Payments::StripeGatewayTest < ActiveSupport::TestCase
  # Records the call instead of calling Stripe.
  class FakeSessions
    attr_reader :params, :options

    def create(params, options)
      @params, @options = params, options
      Struct.new(:id, :url).new("cs_test_123", "https://checkout.stripe.com/c/pay/cs_test_123")
    end
  end

  setup do
    @sessions = FakeSessions.new
    @gateway = Payments::StripeGateway.new(api_key: "sk_test_x", sessions: @sessions)
  end

  test "a one-time gift is a payment session for the exact amount" do
    donation = donations(:pending)
    checkout = @gateway.create_checkout(donation, success_url: "https://s", cancel_url: "https://c")

    assert_equal "cs_test_123", checkout.session_id
    assert_equal "payment", @sessions.params[:mode]
    price = @sessions.params[:line_items].first[:price_data]
    assert_equal 2000, price[:unit_amount]
    assert_equal "eur", price[:currency]
    assert_nil price[:recurring]
    assert_equal donation.public_token, @sessions.params[:client_reference_id]
    assert_equal "checkout-#{donation.public_token}", @sessions.options[:idempotency_key]
  end

  test "a monthly gift is a subscription" do
    donation = donations(:pending)
    donation.frequency = "monthly"
    @gateway.create_checkout(donation, success_url: "https://s", cancel_url: "https://c")

    assert_equal "subscription", @sessions.params[:mode]
    assert_equal({ interval: "month" }, @sessions.params[:line_items].first[:price_data][:recurring])
  end
end
