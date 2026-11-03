# SYNTHETIC fixtures (see factories/users.rb header). The company and
# notice below are invented for tests only.
FactoryBot.define do
  factory :notice do
    company { "Acme Technologies" }
    category { "Software Development Engineer" }
    drive_date { Date.new(2027, 2, 10) }
    eligible_branches { %w[CSE IT ECE] }
    minimum_cgpa { 7.5 }
    minimum_class_x_percentage { 75 }
    minimum_class_xii_percentage { 70 }
    arrears_rule { "no_standing_arrears" }
    ctc { "12 LPA" }
    stipend { "₹30,000/month" }
    registration_deadline { Time.zone.local(2027, 1, 20, 23, 59) }
    registration_url { "https://example.com/acme-register" }
    location { "Bengaluru" }
    source_text { "SYNTHETIC test notice." }
    status { "draft" }
    association :publisher, factory: %i[user coordinator]

    trait :published do
      status { "published" }
    end

    trait :expired do
      registration_deadline { 2.days.ago }
    end
  end

  factory :registration do
    association :user
    association :notice, :published
    status { "registered" }
    registered_at { Time.current }
  end

  factory :reminder do
    association :user
    association :notice, :published
    kind { "publication" }
    scheduled_at { Time.current }
  end
end
