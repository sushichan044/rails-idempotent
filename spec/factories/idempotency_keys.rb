# frozen_string_literal: true

FactoryBot.define do
  factory :idempotency_key do
    key { SecureRandom.uuid }
  end
end
