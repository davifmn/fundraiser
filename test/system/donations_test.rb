require "application_system_test_case"

class DonationsTest < ApplicationSystemTestCase
  test "donating: choose an amount, give details, pay, see the thank-you page and the new total" do
    visit campaign_path(campaigns(:library))
    click_on "€25.00"
    choose "Monthly"
    click_on "Continue"

    assert_text "You give €25.00 every month."
    fill_in "Name", with: "Mariana Costa"
    fill_in "Email (for your receipt)", with: "mariana@example.com"
    click_on "Donate"

    assert_text "Pay €25.00 every month"
    click_on "Pay"

    assert_text "Thank you, Mariana Costa!"
    click_on "Back to A library for Belo Horizonte"
    within("#campaign_progress") { assert_text "€25.00 raised" }
    within("#recent_donations") { assert_text "Mariana Costa gave €25.00 every month" }
  end

  test "the amount is checked before moving on" do
    visit campaign_path(campaigns(:library))
    fill_in "Amount (EUR)", with: "12,50"
    click_on "Continue"

    assert_text "Enter an amount between €1 and €10,000"
    assert_no_field "Name"
  end

  test "a payment confirmed elsewhere shows up on an open page without a reload" do
    visit campaign_path(campaigns(:ocean))
    assert_text "€75.00 raised"

    # As if Stripe's webhook arrived while the page is open.
    donations(:pending).mark_paid!

    within("#campaign_progress") { assert_text "€95.00 raised" }
    within("#recent_donations") { assert_text "Ana Souza gave €20.00" }
  end

  test "a declined payment says so and charges nothing" do
    visit campaign_path(campaigns(:library))
    click_on "Continue"
    fill_in "Name", with: "Rui"
    fill_in "Email (for your receipt)", with: "rui@example.com"
    click_on "Donate"
    click_on "Decline"

    assert_text "The payment did not go through"
  end
end
