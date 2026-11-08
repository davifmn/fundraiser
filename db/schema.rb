# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_08_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "campaigns", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "description", default: "", null: false
    t.bigint "goal_cents", null: false
    t.bigint "raised_cents", default: 0, null: false
    t.integer "donations_count", default: 0, null: false
    t.string "currency", default: "EUR", null: false
    t.date "ends_on"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_campaigns_on_slug", unique: true
    t.check_constraint "goal_cents > 0", name: "campaigns_goal_positive"
    t.check_constraint "raised_cents >= 0 AND donations_count >= 0", name: "campaigns_totals_not_negative"
  end

  create_table "donations", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.string "public_token", null: false
    t.string "donor_name", null: false
    t.string "donor_email", null: false
    t.boolean "anonymous", default: false, null: false
    t.string "message"
    t.bigint "amount_cents", null: false
    t.string "currency", default: "EUR", null: false
    t.string "frequency", default: "one_time", null: false
    t.string "status", default: "pending", null: false
    t.string "checkout_session_id"
    t.string "payment_reference"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "status", "paid_at"], name: "index_donations_on_campaign_id_and_status_and_paid_at"
    t.index ["campaign_id"], name: "index_donations_on_campaign_id"
    t.index ["checkout_session_id"], name: "index_donations_on_checkout_session_id", unique: true
    t.index ["public_token"], name: "index_donations_on_public_token", unique: true
    t.index ["status", "donor_email"], name: "index_donations_on_status_and_donor_email"
    t.check_constraint "(status::text = 'paid'::text) = (paid_at IS NOT NULL)", name: "donations_paid_at_iff_paid"
    t.check_constraint "amount_cents >= 100 AND amount_cents <= 1000000", name: "donations_amount_range"
    t.check_constraint "frequency::text = ANY (ARRAY['one_time'::character varying, 'monthly'::character varying]::text[])", name: "donations_frequency_values"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'paid'::character varying, 'failed'::character varying]::text[])", name: "donations_status_values"
  end

  create_table "webhook_events", force: :cascade do |t|
    t.string "provider", null: false
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.jsonb "payload", null: false
    t.string "outcome"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "event_id"], name: "index_webhook_events_on_provider_and_event_id", unique: true
  end

  add_foreign_key "donations", "campaigns"
end
