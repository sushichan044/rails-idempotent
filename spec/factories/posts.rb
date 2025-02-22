# frozen_string_literal: true

FactoryBot.define do
  factory :post do
    title { 'My first post' }
    content { 'This is my first post' }
  end
end
