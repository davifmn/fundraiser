require "test_helper"

class Reports::DashboardTest < ActiveSupport::TestCase
  test "campaign totals come from paid donations only" do
    row = Reports::Dashboard.new.campaigns.find { |r| r.campaign == campaigns(:ocean) }

    assert_equal 2, row.paid_count
    assert_equal 7500, row.paid_cents
    assert_equal 3750, row.average_cents
    assert_equal 1, row.monthly_donors
    assert_equal 1, row.pending_count
  end

  test "campaigns with no donations still appear, with zeros" do
    row = Reports::Dashboard.new.campaigns.find { |r| r.campaign == campaigns(:library) }
    assert_equal [ 0, 0 ], [ row.paid_count, row.paid_cents ]
  end

  test "top donors exclude anonymous gifts and add up each donor's gifts" do
    campaigns(:library).donations.create!(amount: "100", donor_name: "Anna Weber", donor_email: "anna@example.de").mark_paid!

    donors = Reports::Dashboard.new.top_donors
    assert_equal [ "anna@example.de" ], donors.map(&:email)
    assert_equal 150_00, donors.first.total_cents
    assert_equal 2, donors.first.gifts
  end

  test "daily totals group paid donations by day" do
    days = Reports::Dashboard.new.daily_totals
    assert_equal [ 1, 1 ], days.map(&:gifts)
    assert_equal [ 5000, 2500 ], days.map(&:total_cents)
  end
end
