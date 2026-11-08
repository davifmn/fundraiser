require "test_helper"

class FakeCheckoutsControllerTest < ActionDispatch::IntegrationTest
  test "paying runs the same webhook processing as Stripe" do
    donation = donations(:pending)
    get fake_checkout_path(donation)
    assert_select "h1", /Pay €20.00 once/

    post pay_fake_checkout_path(donation)
    assert_redirected_to donation_path(donation)
    assert donation.reload.paid?
    assert WebhookEvent.exists?(event_type: "checkout.session.completed")
  end

  test "declining fails the donation" do
    donation = donations(:pending)
    post decline_fake_checkout_path(donation)
    assert donation.reload.failed?
  end
end
