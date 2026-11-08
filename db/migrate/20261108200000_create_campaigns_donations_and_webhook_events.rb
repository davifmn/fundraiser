class CreateCampaignsDonationsAndWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.string :title, null: false
      t.string :slug, null: false, index: { unique: true }
      t.text :description, null: false, default: ""
      t.bigint :goal_cents, null: false
      # Denormalized totals, updated atomically with each paid donation, so a campaign
      # page never sums the donations table.
      t.bigint :raised_cents, null: false, default: 0
      t.integer :donations_count, null: false, default: 0
      t.string :currency, null: false, default: "EUR"
      t.date :ends_on
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_check_constraint :campaigns, "goal_cents > 0", name: "campaigns_goal_positive"
    add_check_constraint :campaigns, "raised_cents >= 0 AND donations_count >= 0", name: "campaigns_totals_not_negative"

    create_table :donations do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :public_token, null: false, index: { unique: true }
      t.string :donor_name, null: false
      t.string :donor_email, null: false
      t.boolean :anonymous, null: false, default: false
      t.string :message
      t.bigint :amount_cents, null: false
      t.string :currency, null: false, default: "EUR"
      t.string :frequency, null: false, default: "one_time"
      t.string :status, null: false, default: "pending"
      t.string :checkout_session_id, index: { unique: true }
      t.string :payment_reference
      t.datetime :paid_at
      t.timestamps
    end
    add_index :donations, [ :campaign_id, :status, :paid_at ]
    add_index :donations, [ :status, :donor_email ]
    add_check_constraint :donations, "amount_cents BETWEEN 100 AND 1000000", name: "donations_amount_range"
    add_check_constraint :donations, "status IN ('pending', 'paid', 'failed')", name: "donations_status_values"
    add_check_constraint :donations, "frequency IN ('one_time', 'monthly')", name: "donations_frequency_values"
    add_check_constraint :donations, "(status = 'paid') = (paid_at IS NOT NULL)", name: "donations_paid_at_iff_paid"

    # Every webhook event processed, by provider id: a redelivered event is found here and
    # ignored, so a payment is never counted twice.
    create_table :webhook_events do |t|
      t.string :provider, null: false
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false
      t.string :outcome
      t.timestamps
    end
    add_index :webhook_events, [ :provider, :event_id ], unique: true
  end
end
