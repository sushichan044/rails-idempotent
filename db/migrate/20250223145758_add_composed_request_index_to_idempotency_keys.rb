# frozen_string_literal: true

class AddComposedRequestIndexToIdempotencyKeys < ActiveRecord::Migration[8.0]
  def change
    add_index :idempotency_keys, %i[key request_path request_method],
      name: "index_idempotency_keys_on_request_unique_identifier"
  end
end
