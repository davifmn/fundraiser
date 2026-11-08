# Demo data: `bin/rails db:seed`. Safe to run twice.
campaigns = [
  { slug: "clean-the-baltic", title: "Clean the Baltic Sea", goal_cents: 20_000_00,
    description: "Volunteer divers pull ghost nets and plastic out of harbours from Kiel to Gdańsk.\n\nEvery €25 pays for one dive." },
  { slug: "bh-library", title: "A library for Belo Horizonte", goal_cents: 5_000_00,
    description: "Books, shelves and a reading room for a public school in the north of the city." },
  { slug: "zurich-night-shelter", title: "Winter night shelter in Zürich", goal_cents: 12_000_00,
    description: "Warm beds and breakfast through the coldest weeks of the year." }
]
campaigns.each do |attrs|
  Campaign.find_or_create_by!(slug: attrs[:slug]) { |c| c.assign_attributes(attrs) }
end

if Donation.none?
  donors = [ [ "Anna Weber", "anna@example.de" ], [ "Lukas Meier", "lukas@example.ch" ], [ "Mariana Costa", "mariana@example.com.br" ],
             [ "Jonas Becker", "jonas@example.de" ], [ "Sofia Rossi", "sofia@example.it" ] ]
  Campaign.find_each do |campaign|
    8.times do |i|
      name, email = donors[i % donors.size]
      donation = campaign.donations.create!(
        donor_name: name, donor_email: email, amount: Donation::PRESETS_CENTS.sample / 100,
        frequency: i.even? ? "one_time" : "monthly", anonymous: i == 3, message: ([ "Keep it up!", nil ].sample)
      )
      donation.update!(checkout_session_id: "cs_seed_#{donation.public_token}")
      donation.mark_paid!(payment_reference: "seed")
    end
  end
end
puts "#{Campaign.count} campaigns, #{Donation.paid.count} paid donations"
