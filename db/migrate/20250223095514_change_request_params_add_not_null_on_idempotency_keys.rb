# frozen_string_literal: true

class ChangeRequestParamsAddNotNullOnIdempotencyKeys < ActiveRecord::Migration[8.0]
  def change
    change_column_null :idempotency_keys, :request_params, false
  end
end
