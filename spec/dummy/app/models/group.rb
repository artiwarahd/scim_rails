class Group < ApplicationRecord
  belongs_to :company
  has_many :groups_user
  has_many :users, through: :groups_user

  validates \
    :display_name,
    presence: true,
    uniqueness: true


  def members
    self.users
  end
end
