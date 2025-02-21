# frozen_string_literal: true

# rbs_inline: enabled

class User < ApplicationRecord
  validates :name, presence: true
end
