# frozen_string_literal: true

class NonNullResponseHeadersToIdempotencyKey < ActiveRecord::Migration[8.0]
  def change
    change_column_default :idempotency_keys, :response_headers, from: nil, to: {}
    IdempotencyKey.where(response_headers: nil).map do |idempotency_key|
      idempotency_key.update!(response_headers: {})
    end
    change_column_null :idempotency_keys, :response_headers, false
  end
end
