# frozen_string_literal: true

# rbs_inline: enabled

class IdempotencyKey < ApplicationRecord
  module Error
    class AlreadyLocked < StandardError; end
    class NotLocked < StandardError; end
  end

  class << self
    # @rbs (ActionDispatch::Request) { () -> void } -> void
    def with_request(request, &block)
      idempotency_key = find_by(key: request.headers[:HTTP_IDEMPOTENCY_KEY])
      return if idempotency_key.blank?

      idempotency_key.with_idempotent_lock(&block)
    end
  end

  # @rbs () { () -> void } -> void
  def with_idempotent_lock!
    idempotent_lock!
    begin
      yield
    ensure
      idempotent_unlock!
    end
  end

  # @rbs () -> bool
  def expired?
    expired_at.present? && expired_at < Time.current
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
