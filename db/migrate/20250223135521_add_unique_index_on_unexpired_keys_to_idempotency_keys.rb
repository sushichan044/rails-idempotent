# frozen_string_literal: true

class AddUniqueIndexOnUnexpiredKeysToIdempotencyKeys < ActiveRecord::Migration[8.0]
  def change
    add_index :idempotency_keys, %i[key request_method request_path], unique: true, where: 'expired = false'
  end
end
