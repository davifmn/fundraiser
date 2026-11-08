Rails.application.routes.draw do
  root "campaigns#index"

  resources :campaigns, only: %i[index show], param: :slug do
    resources :donations, only: :create
  end
  resources :donations, only: :show, param: :token

  # Stripe calls this; the signature is checked against STRIPE_WEBHOOK_SECRET.
  post "webhooks/stripe", to: "webhooks#stripe", as: :stripe_webhook

  # Without Stripe keys, a fake checkout page stands in for Stripe's (see Payments::FakeGateway).
  if Payments.fake?
    get "fake_checkout/:token", to: "fake_checkouts#show", as: :fake_checkout
    post "fake_checkout/:token/pay", to: "fake_checkouts#pay", as: :pay_fake_checkout
    post "fake_checkout/:token/decline", to: "fake_checkouts#decline", as: :decline_fake_checkout
  end

  namespace :admin do
    root "dashboard#index"
  end

  # 200 if the app boots, for load balancers and uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check
end
