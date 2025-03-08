# frozen_string_literal: true

class RemoveCompositeIndexOnIdempotentRequest < ActiveRecord::Migration[8.0]
  def change
    remove_index :idempotent_requests, column: %i[key request_path request_method],
      name: :index_idempotency_keys_on_request_unique_identifier
  end
end
