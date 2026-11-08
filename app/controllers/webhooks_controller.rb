# Receives Stripe events. The signature (HMAC of the raw body with the endpoint's secret,
# plus a timestamp against replays) is verified before anything is parsed.
class WebhooksController < ActionController::Base
  skip_forgery_protection

  def stripe
    payload = request.raw_post
    Stripe::Webhook::Signature.verify_header(payload, request.headers["Stripe-Signature"], Payments.webhook_secret, tolerance: 300)
    result = Payments::WebhookProcessor.new.process(JSON.parse(payload))
    render json: { outcome: result.outcome }
  rescue Stripe::SignatureVerificationError, JSON::ParserError, KeyError
    head :bad_request
  end
end
