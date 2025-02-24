# frozen_string_literal: true

# rbs_inline: enabled

module IdempotencyHelpers
  extend ActiveSupport::Concern

  included do
    # @rbs key: String? -- Header value of Idempotency-Key. Must be a UUIDv4. Nil is allowed for utility.
    # @rbs method: String
    # @rbs path: String
    # @rbs params: ActiveSupport::HashWithIndifferentAccess
    # @rbs &block: (IdempotencyKey) -> void
    # @rbs return: ResponseObject
    def ensure_request_idempotency!(key:, method:, path:, params:, &block) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      raise IdempotencyHelpers::Errors::InvalidKey unless valid_key?(key)

      alive_key = IdempotencyKey.find_alive_by_request(idempotency_key: key, method: method, path: path)

      if alive_key && !alive_key.request_match?(method: method, path: path, params: params)
        raise IdempotencyHelpers::Errors::RequestMismatch
      end
      raise IdempotencyHelpers::Errors::KeyLocked if alive_key&.locked?

      if alive_key&.completed?
        return ResponseObject.new(body: alive_key.response_body, status: alive_key.response_code,
                                  headers: alive_key.response_headers)
      end

      # このとき、一度リクエストを処理しようとしたが失敗して response を保存できていない場合は
      # alive_key が存在するので、その alive_key を使って再試行するようにする
      alive_key ||= IdempotencyKey.create!(
        key: key,
        request_method: method,
        request_path: path,
        request_params: params
      )
      alive_key.with_idempotent_lock!(&block)
      raise IdempotencyHelpers::Errors::ResponseNotSet unless alive_key.completed?

      ResponseObject.new(body: alive_key.response_body, status: alive_key.response_code,
                         headers: alive_key.response_headers)
    end
  end

  module Errors
    # 400 Bad Request
    class InvalidKey < StandardError; end
    # 422 Unprocessable Content
    class RequestMismatch < StandardError; end
    # 409 Conflict
    class KeyLocked < StandardError; end

    # 渡されたブロック内で complete_with_response! などを使ってレスポンス情報を格納していない場合に発生
    class ResponseNotSet < StandardError; end
  end

  ResponseObject = Data.define(
    :body, #: String
    :status, #: Integer
    :headers #: Hash[String | Symbol, String]
  )

  private

  # @rbs (String?) -> bool
  def valid_key?(string)
    return false if string.blank?

    begin
      UUIDTools::UUID.parse(string).version == 4
    rescue ArgumentError, TypeError
      false
    end
  end
end
