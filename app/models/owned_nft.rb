class OwnedNft < ApplicationRecord
  belongs_to :account
  belongs_to :nft
  has_many :collections, through: :nft
end
