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
                    conditions: -> { where(expired_at: [nil, Time.current..]) }
                  },
                  on: :create

      idempotency_key.with_idempotent_lock(&block)
    end
  end

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
  def expired?
    expired_at.present? && (expired_at < Time.current)
  end

  # @rbs () -> bool
  def locked?
    locked_at.present?
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
