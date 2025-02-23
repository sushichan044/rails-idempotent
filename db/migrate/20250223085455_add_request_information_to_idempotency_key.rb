# frozen_string_literal: true

class AddRequestInformationToIdempotencyKey < ActiveRecord::Migration[8.0]
  def change
    add_column :idempotency_keys, :request_method, :string, null: false # rubocop:disable Rails/NotNullColumn
    add_column :idempotency_keys, :request_path, :string, null: false # rubocop:disable Rails/NotNullColumn
    add_column :idempotency_keys, :request_params, :json
  end
end
