# frozen_string_literal: true

# rbs_inline: enabled

class User < ApplicationRecord
  has_many :posts, dependent: :delete_all

  validates :name, presence: true
end
