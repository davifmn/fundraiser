module ApplicationHelper
  # 2550 → "€25.50". Amounts are integer cents everywhere; this is the only place they
  # become text.
  def euros(cents)
    "€" + number_with_delimiter(format("%.2f", cents.to_i / 100r))
  end

  def frequency_label(donation)
    donation.monthly? ? "every month" : "once"
  end
end
