# frozen_string_literal: true

# rbs_inline: enabled

module IdempotencyHelpers
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    # @rbs key: String? -- Header value of Idempotency-Key. Must be a UUIDv4. Nil is allowed for utility.
    # @rbs method: String
    # @rbs path: String
    # @rbs params: ActiveSupport::HashWithIndifferentAccess
    # @rbs &block: (IdempotentRequest) -> void
    # @rbs return: ResponseObject
    def ensure_request_idempotency!(key:, method:, path:, params:, &block) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      raise IdempotencyHelpers::Errors::InvalidKey unless valid_key?(key)

      request = IdempotentRequest.find_alive_by_request(idempotency_key: key, method: method, path: path)

      if request
        unless request.same_payload?(method: method, path: path, params: params)
          raise IdempotencyHelpers::Errors::RequestMismatch
        end
        raise IdempotencyHelpers::Errors::KeyLocked if request.locked?

        if request.response_available?
          return ResponseObject.new(body: request.response_body, status: request.response_code,
            headers: request.response_headers)
        end
      end

      # このとき、一度リクエストを処理しようとしたが失敗して response を保存できていない場合は
      # alive_key が存在するので、その alive_key を使って再試行するようにする
      begin
        request ||= IdempotentRequest.create!(
          key: key,
          request_method: method,
          request_path: path,
          request_params: params
        )
      rescue ActiveRecord::RecordNotUnique
        # race condition が発生し、最初に find_alive_by_request で存在しないと判断された後に create が実行されたが、
        # 実際には先行したリクエストが保存されていた場合ここで例外が発生するので、リクエストの同一性判定を再度行う
        preceding = IdempotentRequest.find_alive_by_request(idempotency_key: key, method: method, path: path)
        # この時点で unique in alive に違反しているのに先行リクエストが引けないということは
        # たった今 alive でなくなったということ
        raise IdempotencyHelpers::Errors::KeyIsStale if preceding.blank?

        unless preceding.same_payload?(method: method, path: path, params: params)
          raise IdempotencyHelpers::Errors::RequestMismatch
        end
        raise IdempotencyHelpers::Errors::KeyLocked if preceding.locked?

        if preceding.response_available?
          return ResponseObject.new(body: preceding.response_body, status: preceding.response_code,
            headers: preceding.response_headers)
        end

        raise IdempotencyHelpers::Errors::RaceConditionDetected
      end

      request.with_idempotent_lock!(&block)
      raise IdempotencyHelpers::Errors::ResponseNotSet unless request.response_available?

      ResponseObject.new(body: request.response_body, status: request.response_code,
        headers: request.response_headers)
    end
  end

  module Errors
    # 400 Bad Request
    class InvalidKey < StandardError; end

    # 422 Unprocessable Content
    class RequestMismatch < StandardError; end

    # 409 Conflict
    class KeyLocked < StandardError; end

    # 409 Conflict
    # Please retry with different Idempotency-Key
    class RaceConditionDetected < StandardError; end

    # 400 Bad Request
    class KeyIsStale < StandardError; end

    # 渡されたブロック内で complete_with_response! などを使ってレスポンス情報を格納していない場合に発生
    class ResponseNotSet < StandardError; end
  end

  ResponseObject = Data.define(
    :body, # : String
    :status, # : Integer
    :headers # : Hash[String | Symbol, String]
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
