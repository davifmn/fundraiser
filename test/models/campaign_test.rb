require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  test "progress is a percentage of the goal, capped at 100" do
    campaign = campaigns(:ocean)
    assert_equal 0, campaign.progress_percent # 75 of 20,000 euros
    campaign.raised_cents = 30_000_00
    assert_equal 100, campaign.progress_percent
  end

  test "record_payment! adds to the totals in the database" do
    campaign = campaigns(:library)
    other_copy = Campaign.find(campaign.id) # a stale copy, as another request would hold

    campaign.record_payment!(1000)
    other_copy.record_payment!(500)

    assert_equal 1500, campaign.reload.raised_cents
    assert_equal 2, campaign.donations_count
  end

  test "only open campaigns are listed" do
    assert_includes Campaign.active, campaigns(:ocean)
    assert_not_includes Campaign.active, campaigns(:closed)
    campaigns(:library).update!(ends_on: Date.yesterday)
    assert_not_includes Campaign.active, campaigns(:library)
  end

  test "slugs are lowercase words joined by dashes" do
    assert_not Campaign.new(title: "x", slug: "Not A Slug", goal_cents: 1).valid?
    assert Campaign.new(title: "x", slug: "a-good-slug-2026", goal_cents: 1).valid?
  end
end
