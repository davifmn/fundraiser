require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  AUTH = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret") }.freeze

  test "the dashboard needs the organizer's password" do
    get admin_root_path
    assert_response :unauthorized
  end

  test "it shows campaign totals, top donors and the latest donations" do
    get admin_root_path, headers: AUTH
    assert_response :success
    assert_select "td", "Clean the Baltic Sea"
    assert_select "td", "anna@example.de"
    assert_select "tbody tr[id^=admin_donation]", 3
  end

  # Every section is one aggregate query or a preloaded list, so the number of queries
  # must not grow with the number of donations (Bullet also fails the test on an N+1).
  test "the number of queries does not grow with the data" do
    baseline = count_queries { get admin_root_path, headers: AUTH }

    15.times do |i|
      campaigns(:library).donations.create!(amount: "#{i + 5}", donor_name: "D#{i}", donor_email: "d#{i}@example.com").mark_paid!
    end
    after = count_queries { get admin_root_path, headers: AUTH }

    assert_equal baseline, after
  end

  private

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:sql].start_with?("SAVEPOINT", "RELEASE") }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
