# frozen_string_literal: true

# rbs_inline: enabled

class UsersController < ApplicationController
  include IdempotencyHelpers

  def create
    user = User.new(user_params)
    render json: {data: nil, error: user.errors}, status: :unprocessable_content and return unless user.valid?

    begin
      response = ensure_request_idempotency!(
        key: extract_idempotency_key, method: request.request_method, path: request.path,
        params: params.to_unsafe_h
      ) do |req|
        user.save!
        req.set_response!(body: user.to_json, status: 201)
      end
    rescue IdempotencyHelpers::Errors::InvalidKey
      render json: {data: nil, error: "Idempotency-Key is invalid"}, status: :bad_request
      return
    rescue IdempotencyHelpers::Errors::RequestMismatch
      render json: {data: nil, error: "Idempotency-Key is already used"}, status: :unprocessable_content
      return
    rescue IdempotencyHelpers::Errors::KeyLocked
      render json: {data: nil, error: "A request is outstanding for this Idempotency-Key"}, status: :conflict
      return
    rescue IdempotencyHelpers::Errors::RaceConditionDetected
      render json: {data: nil, error: "Race condition detected. Please retry with different Idempotency-Key"},
        status: :conflict
      return
    rescue IdempotencyHelpers::Errors::KeyIsStale
      render json: {data: nil, error: "Idempotency-Key is stale. Please retry with different Idempotency-Key"},
        status: :bad_request
      return
    end

    render json: {data: response.body, error: nil}, status: response.status, headers: response.headers
  end

  def show
    if (user = User.find_by(id: params[:id])).present?
      render json: {data: user, error: nil}, status: :ok
    else
      render json: {data: nil, error: "User not found"}, status: :not_found
    end
  end

  def update
    if (user = User.find_by(id: params[:id])).nil?
      render json: {data: nil, error: "User not found"}, status: :not_found
      return
    end

    if user.update(user_params)
      render json: {data: user, error: nil}, status: :ok
    else
      render json: {data: nil, error: user.errors}, status: :unprocessable_content
    end
  end

  def destroy
    if (user = User.find_by(id: params[:id])).nil?
      render json: {data: nil, error: "User not found"}, status: :not_found
      return
    end

    if user.destroy
      render json: {data: "User with id #{params[:id]} has been deleted", error: nil}, status: :ok
    else
      render json: {data: nil, error: user.errors}, status: :unprocessable_content
    end
  end

  private

  # @rbs () -> { name: String? }
  def user_params
    params.expect(user: [:name])
  end

  # @rbs () -> String?
  def extract_idempotency_key
    request.headers["HTTP_IDEMPOTENCY_KEY"]
  end
end
