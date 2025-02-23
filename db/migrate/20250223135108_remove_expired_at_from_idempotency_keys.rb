# frozen_string_literal: true

class RemoveExpiredAtFromIdempotencyKeys < ActiveRecord::Migration[8.0]
  def change
    remove_column :idempotency_keys, :expired_at, :datetime
  end
end
