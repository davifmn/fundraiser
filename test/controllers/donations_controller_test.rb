require "test_helper"

class DonationsControllerTest < ActionDispatch::IntegrationTest
  def donate(campaign, **attrs)
    post campaign_donations_path(campaign), params: {
      donation: { amount: "25", frequency: "monthly", donor_name: "Ana Souza", donor_email: "ana@example.com" }.merge(attrs)
    }
  end

  test "a valid donation is saved as pending and goes to the checkout page" do
    assert_difference -> { Donation.pending.count } do
      donate campaigns(:library)
    end
    donation = Donation.order(:created_at).last
    assert_redirected_to fake_checkout_path(donation)
    assert_response :see_other
    assert_equal 2500, donation.amount_cents
    assert donation.monthly?
    assert_equal "cs_fake_#{donation.public_token}", donation.checkout_session_id
  end

  test "an invalid donation re-renders the form with the errors" do
    assert_no_difference -> { Donation.count } do
      donate campaigns(:library), amount: "0.50", donor_email: "nope"
    end
    assert_response :unprocessable_content
    assert_select ".errors", /between €1 and €10,000/
  end

  test "a closed campaign refuses donations" do
    donate campaigns(:closed)
    assert_response :unprocessable_content
    assert_select ".errors", /not accepting donations/
  end

  test "the thank-you page is found by its token only" do
    get donation_path(donations(:anna))
    assert_response :success
    assert_select "h1", /Thank you, Anna Weber/

    get donation_path("not-a-token")
    assert_response :not_found
  end

  test "the campaign page shows totals and recent supporters" do
    get campaign_path(campaigns(:ocean))
    assert_response :success
    assert_select "#campaign_progress", /€75.00/
    assert_select "#recent_donations li", 2
    assert_select "#recent_donations", /Anonymous/
  end
end
