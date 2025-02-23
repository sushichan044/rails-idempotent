# frozen_string_literal: true

class AddResponseDatasToIdempotencyKey < ActiveRecord::Migration[8.0]
  def change
    add_column :idempotency_keys, :response_code, :integer
    add_column :idempotency_keys, :response_body, :string
    add_column :idempotency_keys, :response_headers, :json
  end
end
