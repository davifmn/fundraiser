require "test_helper"

class DonationTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def new_donation(**attrs)
    campaigns(:library).donations.new({ amount: "25", donor_name: "Ana", donor_email: "ana@example.com" }.merge(attrs))
  end

  test "amounts are read exactly, never rounded" do
    assert_equal 2550, new_donation(amount: "25.50").amount_cents
    assert_equal 2500, new_donation(amount: " 25 ").amount_cents
    %w[1e3 -5 10,50 0.001 abc].each do |bad|
      donation = new_donation(amount: bad)
      assert_not donation.valid?, bad
      assert_includes donation.errors[:amount_cents], "must be between €1 and €10,000"
    end
  end

  test "the amount must be between 1 and 10,000 euros" do
    assert new_donation(amount: "1").valid?
    assert new_donation(amount: "10000").valid?
    assert_not new_donation(amount: "0.99").valid?
    assert_not new_donation(amount: "10000.01").valid?
  end

  test "donor details are required and checked" do
    donation = new_donation(donor_name: "", donor_email: "not-an-email", message: "x" * 141)
    assert_not donation.valid?
    assert donation.errors[:donor_name].any?
    assert donation.errors[:donor_email].any?
    assert donation.errors[:message].any?
  end

  test "a closed campaign takes no donations" do
    donation = campaigns(:closed).donations.new(amount: "10", donor_name: "Ana", donor_email: "ana@example.com")
    assert_not donation.valid?
    assert_includes donation.errors[:campaign], "is not accepting donations"
  end

  test "each donation gets an unguessable public token" do
    donation = new_donation
    donation.save!
    assert_operator donation.public_token.length, :>=, 24
    assert_equal donation.public_token, donation.to_param
  end

  test "mark_paid! counts the payment once, and sends one receipt" do
    donation = donations(:pending)
    campaign = donation.campaign

    assert_enqueued_emails 1 do
      assert donation.mark_paid!(payment_reference: "pi_1")
      assert_not donation.mark_paid!(payment_reference: "pi_1"), "a second confirmation changes nothing"
    end

    assert donation.reload.paid?
    assert_not_nil donation.paid_at
    assert_equal 7500 + 2000, campaign.reload.raised_cents
    assert_equal 3, campaign.donations_count
  end

  test "only a pending donation can fail" do
    assert donations(:pending).mark_failed!
    assert donations(:pending).reload.failed?
    assert_not donations(:anna).mark_failed!, "a paid donation stays paid"
  end

  test "anonymous donors are shown as such" do
    assert_equal "Anonymous", donations(:lukas).display_name
    assert_equal "Anna Weber", donations(:anna).display_name
  end

  test "the database refuses a paid donation without a payment date" do
    assert_raises(ActiveRecord::StatementInvalid) do
      donations(:pending).update_columns(status: "paid")
    end
  end
end
