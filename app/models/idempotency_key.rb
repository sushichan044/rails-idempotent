# frozen_string_literal: true

# rbs_inline: enabled

class IdempotencyKey < ApplicationRecord
  module Error
    class AlreadyLocked < StandardError; end
    class NotLocked < StandardError; end
  end

  validates :key, presence: true, uuid: { version: 4 }
  validates :key, uniqueness: {
                    scope: %i[request_method request_path],
                    # Only unique in unexpired
                    conditions: -> { unexpired }
                  },
                  on: :create

  validates :request_method, presence: true, length: { maximum: 10 }
  validates :request_path, presence: true, length: { maximum: 255 }
  validates :request_params, presence: true

  scope :unexpired, -> {}

  # @rbs [T] () { () -> T } -> T
  def with_idempotent_lock!
    return unless block_given?

    idempotent_lock!
    begin
      yield
    ensure
      idempotent_unlock!
    end
  end

  # @rbs () -> bool
  def locked?
    locked_at.present?
  end

  # @rbs (method: String, path: String, params: ActiveSupport::HashWithIndifferentAccess) -> bool
  def request_mismatch?(method:, path:, params:)
    request_method != method ||
      request_path != path ||
      request_params != params.to_h
  end

  private

  # @rbs () -> void
  def idempotent_lock!
    with_lock do
      raise Error::AlreadyLocked if locked?

      update!(locked_at: Time.current)
    end
  end

  # @rbs () -> void
  def idempotent_unlock!
    with_lock do
      raise Error::NotLocked unless locked?

      update!(locked_at: nil)
    end
  end
end
