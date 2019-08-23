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

  def add_members!(member_ids)
    self.users = self.users | User.find(member_ids)
  end

  def remove_members!(member_ids)
    self.users = self.users - User.find(member_ids)
  end
end
