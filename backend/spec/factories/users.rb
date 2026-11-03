# All factory data below is SYNTHETIC test data: invented users, companies,
# and notices used only to exercise correctness in an isolated test database.
# Nothing here is a real student, company, or placement notice.
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "student#{n}@example.com" }
    password { "password1234" }
    role { "student" }
    branch { "CSE" }
    cgpa { 8.0 }
    class_x_percentage { 85 }
    class_xii_percentage { 82 }
    standing_arrears { false }

    trait :coordinator do
      sequence(:email) { |n| "coordinator#{n}@example.com" }
      role { "coordinator" }
      branch { nil }
      cgpa { nil }
      class_x_percentage { nil }
      class_xii_percentage { nil }
    end

    trait :incomplete_profile do
      branch { nil }
      cgpa { nil }
      class_x_percentage { nil }
      class_xii_percentage { nil }
    end

    trait :with_arrears do
      standing_arrears { true }
    end
  end
end
