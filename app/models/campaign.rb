class Campaign < ApplicationRecord
  has_many :donations, dependent: :restrict_with_error

  validates :title, presence: true, length: { maximum: 120 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :goal_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, inclusion: { in: %w[EUR] }

  scope :active, -> { where(active: true).where("ends_on IS NULL OR ends_on >= ?", Date.current) }

  def to_param = slug

  def progress_percent
    [ raised_cents * 100 / goal_cents, 100 ].min
  end

  def open? = active && (ends_on.nil? || ends_on >= Date.current)

  # Adds a paid donation to the totals in one UPDATE, so concurrent payments cannot lose
  # each other's increments (no read-modify-write in Ruby).
  def record_payment!(amount_cents)
    self.class.where(id: id).update_all(
      [ "raised_cents = raised_cents + ?, donations_count = donations_count + 1, updated_at = ?", amount_cents, Time.current ]
    )
    reload
  end

  def recent_donations(limit = 10)
    donations.paid.order(paid_at: :desc).limit(limit)
  end
end
