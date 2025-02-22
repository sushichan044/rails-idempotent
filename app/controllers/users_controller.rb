# frozen_string_literal: true

# rbs_inline: enabled

class UsersController < ApplicationController
  def create
    user = User.new(user_params)

    if user.save
      render json: { data: user, error: nil }, status: :created
    else
      render json: { data: nil, error: user.errors }, status: :unprocessable_content
    end
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
end
