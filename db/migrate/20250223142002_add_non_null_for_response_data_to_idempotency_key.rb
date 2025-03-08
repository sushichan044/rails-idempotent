# frozen_string_literal: true

class AddNonNullForResponseDataToIdempotencyKey < ActiveRecord::Migration[8.0]
  def change
    change_column_default :idempotency_keys, :response_body, from: nil, to: ""
    change_column_default :idempotency_keys, :response_code, from: nil, to: 0

    change_column_null :idempotency_keys, :response_body, false
    change_column_null :idempotency_keys, :response_code, false
  end
end
