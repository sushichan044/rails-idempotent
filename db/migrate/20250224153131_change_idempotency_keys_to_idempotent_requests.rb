# frozen_string_literal: true

class ChangeIdempotencyKeysToIdempotentRequests < ActiveRecord::Migration[8.0]
  def change
    rename_table :idempotency_keys, :idempotent_requests
  end
end
