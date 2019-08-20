FactoryBot.define do
  factory :group do
    company
    sequence(:display_name) { |n| "Group ##{n}" }
  end
end
