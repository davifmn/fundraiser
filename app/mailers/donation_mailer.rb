class DonationMailer < ApplicationMailer
  def receipt(donation)
    @donation = donation
    @campaign = donation.campaign
    mail to: donation.donor_email, subject: "Thank you for supporting #{@campaign.title}"
  end
end
