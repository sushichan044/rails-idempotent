# frozen_string_literal: true

# rbs_inline: enabled

class Post < ApplicationRecord
  belongs_to :user

  validates :title, presence: true, length: { maximum: 100 }
  validates :content, presence: true, length: { maximum: 1000 }

  alias author user
end
