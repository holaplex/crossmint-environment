class Account < ApplicationRecord
  has_many :owned_nfts
  has_many :nfts, through: :owned_nfts
  has_many :collections, through: :nfts

  def name
    "#{last_name}, #{first_name}"
  end
end
