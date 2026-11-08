# The checkout page used when Stripe is not configured. "Pay" and "Decline" produce the
# same events Stripe would send and run them through the same WebhookProcessor, so the
# rest of the application cannot tell the difference.
class FakeCheckoutsController < ApplicationController
  before_action :set_donation

  def show
  end

  def pay
    complete "checkout.session.completed", payment_status: "paid"
  end

  def decline
    complete "checkout.session.expired"
  end

  private

  def set_donation
    @donation = Donation.find_by!(public_token: params[:token])
  end

  def complete(type, payment_status: nil)
    Payments::WebhookProcessor.new.process(Payments::FakeGateway.event(@donation, type, payment_status: payment_status))
    redirect_to donation_path(@donation), status: :see_other
  end
end
