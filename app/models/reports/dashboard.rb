module Reports
  # The organizer's numbers, computed by PostgreSQL: each section is one query with
  # GROUP BY, so the page costs the same whether there are ten donations or a million rows
  # to aggregate (the test checks the query count does not grow with the data).
  class Dashboard
    CampaignRow = Data.define(:campaign, :paid_count, :paid_cents, :average_cents, :monthly_donors, :pending_count, :failed_count)
    DonorRow = Data.define(:email, :name, :total_cents, :gifts)
    DayRow = Data.define(:day, :total_cents, :gifts)

    def campaigns
      stats = Donation.group(:campaign_id).pluck(
        :campaign_id,
        Arel.sql("COUNT(*) FILTER (WHERE status = 'paid')"),
        Arel.sql("COALESCE(SUM(amount_cents) FILTER (WHERE status = 'paid'), 0)"),
        Arel.sql("COALESCE(ROUND(AVG(amount_cents) FILTER (WHERE status = 'paid')), 0)"),
        Arel.sql("COUNT(DISTINCT donor_email) FILTER (WHERE status = 'paid' AND frequency = 'monthly')"),
        Arel.sql("COUNT(*) FILTER (WHERE status = 'pending')"),
        Arel.sql("COUNT(*) FILTER (WHERE status = 'failed')")
      ).index_by(&:first)

      Campaign.order(:created_at).map do |c|
        _, paid, cents, avg, monthly, pending, failed = stats.fetch(c.id, [ c.id, 0, 0, 0, 0, 0, 0 ])
        CampaignRow.new(c, paid, cents, avg.to_i, monthly, pending, failed)
      end
    end

    def top_donors(limit = 10)
      Donation.paid.where(anonymous: false)
              .group(:donor_email)
              .order(Arel.sql("SUM(amount_cents) DESC"))
              .limit(limit)
              .pluck(:donor_email, Arel.sql("MAX(donor_name)"), Arel.sql("SUM(amount_cents)"), Arel.sql("COUNT(*)"))
              .map { |row| DonorRow.new(*row) }
    end

    def daily_totals(days = 30)
      Donation.paid.where(paid_at: days.days.ago.beginning_of_day..)
              .group(Arel.sql("date_trunc('day', paid_at)::date"))
              .order(Arel.sql("date_trunc('day', paid_at)::date"))
              .pluck(Arel.sql("date_trunc('day', paid_at)::date"), Arel.sql("SUM(amount_cents)"), Arel.sql("COUNT(*)"))
              .map { |row| DayRow.new(*row) }
    end

    # The latest donations with their campaign, preloaded: one query for the donations and
    # one for their campaigns, however many rows (Bullet fails the tests on an N+1).
    def latest(limit = 20)
      Donation.includes(:campaign).order(created_at: :desc).limit(limit)
    end
  end
end
