# frozen_string_literal: true

class AddLockedAtToIdempotencyKey < ActiveRecord::Migration[8.0]
  def change
    add_column :idempotency_keys, :locked_at, :datetime
  end
end
