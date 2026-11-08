class CampaignsController < ApplicationController
  def index
    @campaigns = Campaign.active.order(:created_at)
  end

  def show
    @campaign = Campaign.find_by!(slug: params[:slug])
    @donation = @campaign.donations.new(amount: "25", frequency: "one_time")
    @recent_donations = @campaign.recent_donations
  end
end
