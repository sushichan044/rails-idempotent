# frozen_string_literal: true

FactoryBot.define do
  factory :idempotent_request do
    key { SecureRandom.uuid_v4 }
    request_method { 'POST' }
    request_path { '/test' }
    request_params { { foo: 'bar' } }
  end
end
