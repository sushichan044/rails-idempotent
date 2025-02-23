# frozen_string_literal: true

# rbs_inline: enabled

module IdempotentRequest
  extend ActiveSupport::Concern

  included do
    # @rbs key: String? -- Header value of Idempotency-Key. Must be a UUIDv4. Nil is allowed for utility.
    # @rbs method: String
    # @rbs path: String
    # @rbs params: ActiveSupport::HashWithIndifferentAccess
    # @rbs &block: (IdempotencyKey) -> void
    # @rbs return: { body: String, status: Integer, headers: Hash }
    def with_idempotent_request!(key:, method:, path:, params:, &block) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      raise IdempotentRequest::IdempotencyError::InvalidKey unless valid_key?(key)

      alive_key = IdempotencyKey.find_alive_by_request(idempotency_key: key, method: method, path: path)

      if alive_key && !alive_key.request_match?(method: method, path: path, params: params)
        raise IdempotentRequest::IdempotencyError::RequestMismatch
      end
      raise IdempotentRequest::IdempotencyError::KeyLocked if alive_key&.locked?

      if alive_key&.completed?
        Rails.logger.info("Request with Idempotency-Key #{key} is already completed. Returning the cached response.")
        return {
          body: alive_key.response_body,
          status: alive_key.response_code,
          headers: alive_key.response_headers
        }
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
      raise 'Response was not set in with_idempotent_lock!' unless alive_key.completed?

      { body: alive_key.response_body, status: alive_key.response_code, headers: alive_key.response_headers }
    end
  end

  module IdempotencyError
    # 400 Bad Request
    class InvalidKey < StandardError; end
    # 422 Unprocessable Content
    class RequestMismatch < StandardError; end
    # 409 Conflict
    class KeyLocked < StandardError; end
  end

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
