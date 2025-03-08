# frozen_string_literal: true

class AddSingleIndexForKeyOnIdempotentRequest < ActiveRecord::Migration[8.0]
  def change
    add_index :idempotent_requests, :key, unique: true
  end
end
