class Conference < ApplicationRecord
  has_many :schools
  has_many :collections
  has_one :conference
end
