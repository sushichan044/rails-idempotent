# frozen_string_literal: true

class AddDefaultToIdempotencyKeys < ActiveRecord::Migration[8.0]
  def change
    change_column_default :idempotency_keys, :request_method, from: nil, to: ''
    change_column_default :idempotency_keys, :request_path, from: nil, to: ''
    change_column_default :idempotency_keys, :request_params, from: nil, to: {}
  end
end
