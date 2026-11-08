class DonationsController < ApplicationController
  # A bot hammering the form would create pending donations and checkout sessions.
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to campaigns_path, alert: "Too many attempts. Try again in a minute." }

  def create
    @campaign = Campaign.find_by!(slug: params[:campaign_slug])
    @donation = @campaign.donations.new(donation_params)
    unless @donation.save
      @recent_donations = @campaign.recent_donations
      return render "campaigns/show", status: :unprocessable_content
    end

    checkout = Payments.gateway.create_checkout(@donation, success_url: donation_url(@donation), cancel_url: campaign_url(@campaign))
    @donation.update!(checkout_session_id: checkout.session_id)
    redirect_to checkout.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    Rails.logger.error("checkout for donation #{@donation&.public_token} failed: #{e.message}")
    @donation&.mark_failed!
    redirect_to campaign_path(@campaign), alert: "The payment page is unavailable right now. You have not been charged."
  end

  def show
    @donation = Donation.includes(:campaign).find_by!(public_token: params[:token])
  end

  private

  def donation_params
    params.expect(donation: %i[amount frequency donor_name donor_email anonymous message])
  end
end
