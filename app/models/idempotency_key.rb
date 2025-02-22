# frozen_string_literal: true

# rbs_inline: enabled

class IdempotencyKey < ApplicationRecord
  # @rbs () { () -> void } -> void
  def with_idempotent_lock(&_block)
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
    locked_at.present? && locked_at > Time.current
  end

  private

  # @rbs () -> void
  def idempotent_lock!
    with_lock do
      raise 'Already locked' if locked?

      self.locked_at = Time.current
    end
    nil
  end

  # @rbs () -> void
  def idempotent_unlock!
    with_lock do
      raise 'Not locked' unless locked?

      self.locked_at = nil
    end
  end
end
