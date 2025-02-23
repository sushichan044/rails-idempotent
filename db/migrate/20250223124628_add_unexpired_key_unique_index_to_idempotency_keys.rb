# frozen_string_literal: true

class AddUnexpiredKeyUniqueIndexToIdempotencyKeys < ActiveRecord::Migration[8.0]
  def change
    add_index :idempotency_keys, %i[key request_method request_path], unique: true,
                                                                      where: "expired_at IS NULL OR expired_at > date('now')" # rubocop:disable Layout/LineLength
  end
end
