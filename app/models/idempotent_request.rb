# frozen_string_literal: true

# rbs_inline: enabled

class IdempotentRequest < ApplicationRecord
  module Error
    class AlreadyLocked < StandardError; end

    class NotLocked < StandardError; end
  end

  # 24時間ちょうどまでは保存されたレスポンスが有効。1 秒でも過ぎたら無効
  EXPIRES_IN = 24.hours # : ActiveSupport::Duration

  validates :key, presence: true, uuid: {version: 4}
  validate :validate_unique_alive_key, on: :create

  validates :request_method, presence: true, length: {maximum: 10}
  validates :request_path, presence: true, length: {maximum: 255}
  validates :request_params, presence: true

  scope :alive, -> { where(updated_at: EXPIRES_IN.ago..) }

  class << self
    # @rbs (idempotency_key: String, method: String, path: String) -> IdempotentRequest?
    def find_alive_by_request(idempotency_key:, method:, path:)
      # 2025.02.24 に実行計画を見た感じでは index_idempotency_keys_on_request_unique_identifier が効いていそう
      alive.find_by(key: idempotency_key, request_path: path, request_method: method)
    end
  end

  # @rbs [T] () { (IdempotentRequest) -> T } -> T
  #    | () -> void
  def with_idempotent_lock!
    return unless block_given?

    idempotent_lock!
    begin
      yield(self)
    ensure
      idempotent_unlock!
    end
  end

  # @rbs (body: String, status: Integer, headers: Hash) -> void
  def set_response!(body:, status:, headers: {})
    update!(
      response_body: body,
      response_code: status,
      response_headers: headers
    )
  end

  # Idempotency-Key に対応するリクエストが処理途中の場合のみ true を返す
  # @rbs () -> bool
  def locked?
    locked_at.present?
  end

  # @rbs (method: String, path: String, params: ActiveSupport::HashWithIndifferentAccess) -> bool
  def same_payload?(method:, path:, params:)
    request_method == method &&
      request_path == path &&
      request_params == params.to_h
  end

  # IdempotentRequest が有効期限内であるか
  # @rbs () -> bool
  def alive?
    updated_at >= EXPIRES_IN.ago
  end

  # IdempotentRequest に紐ついたリクエストの処理が完了しレスポンスが利用可能か
  # @rbs () -> bool
  def response_available?
    # response_header はなくても良いので、response が指定されているかどうかの判定に使わない
    response_body.present? && response_code != 0
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

  # @rbs () -> void
  def validate_unique_alive_key
    # 過去 24 時間以内に作成 / 更新されている場合は、同じ key / method / path のリクエストを新規に受け付けない
    # 2025.02.24 に実行計画を見た感じでは index_idempotency_keys_on_request_unique_identifier が効いていそう
    condition = self.class.where(key: key, request_method: request_method, request_path: request_path).alive
    return unless condition.exists?

    errors.add(:key, "must be unique in alive and not completed")
  end
end
