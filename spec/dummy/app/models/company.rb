class Company < ApplicationRecord
  has_many :groups
  has_many :users
end
