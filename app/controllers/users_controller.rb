# frozen_string_literal: true

# rbs_inline: enabled

class UsersController < ApplicationController
  include IdempotencyHelpers

  def create # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    user = User.new(user_params)
    render json: { data: nil, error: user.errors }, status: :unprocessable_content and return unless user.valid?

    begin
      response = ensure_request_idempotency!(
        key: extract_idempotency_key, method: request.request_method, path: request.path,
        params: params.to_unsafe_h
      ) do |key|
        user.save!
        key.complete_with_response!(body: user.to_json, status: 201)
      end
    rescue Errors::InvalidKey
      render json: { data: nil, error: 'Idempotency-Key is invalid' }, status: :bad_request
      return
    rescue Errors::RequestMismatch
      render json: { data: nil, error: 'Idempotency-Key is already used' }, status: :unprocessable_content
      return
    rescue Errors::KeyLocked
      render json: { data: nil, error: 'A request is outstanding for this Idempotency-Key' }, status: :conflict
      return
    end

    render json: { data: JSON.parse(response.body), error: nil }, status: response.status, headers: response.headers
  end

  def show
    if (user = User.find_by(id: params[:id])).present?
      render json: { data: user, error: nil }, status: :ok
    else
      render json: { data: nil, error: 'User not found' }, status: :not_found
    end
  end

  def update
    if (user = User.find_by(id: params[:id])).nil?
      render json: { data: nil, error: 'User not found' }, status: :not_found
      return
    end

    if user.update(user_params)
      render json: { data: user, error: nil }, status: :ok
    else
      render json: { data: nil, error: user.errors }, status: :unprocessable_content
    end
  end

  def destroy
    if (user = User.find_by(id: params[:id])).nil?
      render json: { data: nil, error: 'User not found' }, status: :not_found
      return
    end

    if user.destroy
      render json: { data: "User with id #{params[:id]} has been deleted", error: nil }, status: :ok
    else
      render json: { data: nil, error: user.errors }, status: :unprocessable_content
    end
  end

  private

  # @rbs () -> { name: String? }
  def user_params
    params.expect(user: [:name])
  end

  # @rbs () -> String?
  def extract_idempotency_key
    request.headers['HTTP_IDEMPOTENCY_KEY']
  end
end
