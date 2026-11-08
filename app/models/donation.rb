class Donation < ApplicationRecord
  PRESETS_CENTS = [ 10_00, 25_00, 50_00, 100_00 ].freeze
  MIN_CENTS = 1_00
  MAX_CENTS = 10_000_00

  belongs_to :campaign

  enum :status, { pending: "pending", paid: "paid", failed: "failed" }, default: "pending", validate: true
  enum :frequency, { one_time: "one_time", monthly: "monthly" }, default: "one_time", validate: true

  validates :donor_name, presence: true, length: { maximum: 100 }
  validates :donor_email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, length: { maximum: 140 }
  validates :amount_cents, numericality: {
    only_integer: true, greater_than_or_equal_to: MIN_CENTS, less_than_or_equal_to: MAX_CENTS,
    message: "must be between €1 and €10,000"
  }
  validate :campaign_is_open, on: :create

  before_validation :assign_public_token, on: :create

  after_commit :announce_payment, if: -> { saved_change_to_status? && paid? }

  def to_param = public_token

  # "25.50" → 2550. Anything that would have to be rounded or is not a plain decimal
  # ("1e3", "-5", "10,5", "0.001") becomes nil, which the validation reports.
  def amount=(value)
    text = value.to_s.strip
    self.amount_cents = text.match?(/\A\d{1,7}(\.\d{1,2})?\z/) ? (BigDecimal(text) * 100).to_i : nil
  end

  def amount
    amount_cents && format("%.2f", amount_cents / 100.0)
  end

  def display_name = anonymous? ? "Anonymous" : donor_name

  # Called by the payment webhook. Idempotent: only a pending donation becomes paid, and
  # the row lock makes two concurrent deliveries of the same payment wait for each other,
  # so the campaign total is incremented exactly once.
  def mark_paid!(payment_reference: nil)
    with_lock do
      return false unless pending?

      update!(status: :paid, paid_at: Time.current, payment_reference: payment_reference)
      campaign.record_payment!(amount_cents)
    end
    true
  end

  def mark_failed!
    with_lock do
      return false unless pending?

      update!(status: :failed)
    end
    true
  end

  private

  def assign_public_token
    self.public_token ||= SecureRandom.urlsafe_base64(18)
  end

  def campaign_is_open
    errors.add(:campaign, "is not accepting donations") if campaign && !campaign.open?
  end

  # After the commit, so that what is broadcast and mailed is what the database holds.
  def announce_payment
    campaign.reload
    campaign.broadcast_replace_to campaign, target: "campaign_progress", partial: "campaigns/progress", locals: { campaign: campaign }
    broadcast_prepend_to campaign, target: "recent_donations", partial: "donations/donation", locals: { donation: self }
    broadcast_replace_to self, target: "donation_status", partial: "donations/status", locals: { donation: self }
    DonationMailer.receipt(self).deliver_later
  end
end
