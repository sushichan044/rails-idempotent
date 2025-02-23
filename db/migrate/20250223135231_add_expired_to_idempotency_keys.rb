# frozen_string_literal: true

class AddExpiredToIdempotencyKeys < ActiveRecord::Migration[8.0]
  def change
    add_column :idempotency_keys, :expired, :boolean, null: false, default: false
  end
end
