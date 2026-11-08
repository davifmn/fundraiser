require "test_helper"

class DonationMailerTest < ActionMailer::TestCase
  test "the receipt states the amount, the frequency and a reference" do
    mail = DonationMailer.receipt(donations(:anna))

    assert_equal [ "anna@example.de" ], mail.to
    assert_equal "Thank you for supporting Clean the Baltic Sea", mail.subject
    assert_match "€50.00 every month", mail.text_part.body.to_s
    assert_match "tok-anna", mail.html_part.body.to_s
  end
end
