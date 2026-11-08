require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  include WebhookHelper

  setup { @donation = donations(:pending) }

  test "a paid checkout marks the donation paid and adds it to the campaign" do
    post_stripe_event completed_event(@donation)

    assert_response :success
    assert_equal "paid", response.parsed_body["outcome"]
    assert @donation.reload.paid?
    assert_equal "pi_123", @donation.payment_reference
    assert_equal 9500, @donation.campaign.reload.raised_cents
  end

  test "a resent event is acknowledged and ignored" do
    event = completed_event(@donation, id: "evt_same")
    post_stripe_event event
    post_stripe_event event

    assert_equal "duplicate", response.parsed_body["outcome"]
    assert_equal 9500, @donation.campaign.reload.raised_cents, "counted once"
    assert_equal 1, WebhookEvent.where(event_id: "evt_same").count
  end

  test "a second event for the same payment does not count it again" do
    post_stripe_event completed_event(@donation)
    post_stripe_event completed_event(@donation).merge("type" => "checkout.session.async_payment_succeeded")

    assert_equal "already_settled", response.parsed_body["outcome"]
    assert_equal 9500, @donation.campaign.reload.raised_cents
  end

  test "an expired checkout fails the donation" do
    event = completed_event(@donation).merge("type" => "checkout.session.expired")
    event["data"]["object"]["payment_status"] = "unpaid"
    post_stripe_event event

    assert @donation.reload.failed?
    assert_equal 7500, @donation.campaign.reload.raised_cents
  end

  test "a bad or missing signature is refused before anything is parsed" do
    post_stripe_event completed_event(@donation), secret: "whsec_wrong"
    assert_response :bad_request

    post stripe_webhook_path, params: completed_event(@donation).to_json, headers: { "Content-Type" => "application/json" }
    assert_response :bad_request
    assert @donation.reload.pending?
  end

  test "an old signature is refused (replay protection)" do
    post_stripe_event completed_event(@donation), at: 10.minutes.ago
    assert_response :bad_request
  end

  test "an amount that differs from the pledge is an error and the event is not recorded" do
    assert_raises(ArgumentError) { post_stripe_event completed_event(@donation, id: "evt_bad", amount: 1) }
    assert_not WebhookEvent.exists?(event_id: "evt_bad"), "not recorded, so Stripe's retry processes it once fixed"
    assert @donation.reload.pending?
  end

  test "events about something else are acknowledged and ignored" do
    post_stripe_event({ "id" => "evt_other", "type" => "customer.created", "data" => { "object" => { "object" => "customer" } } })
    assert_response :success
    assert_equal "ignored", response.parsed_body["outcome"]
  end
end
