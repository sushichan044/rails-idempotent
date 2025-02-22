# frozen_string_literal: true

class CreateIdempotencyKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :idempotency_keys do |t|
      t.string :key, null: false
      t.datetime :expired_at

      t.timestamps
    end
  end
end
