# frozen_string_literal: true

# rbs_inline: enabled

class ApplicationController < ActionController::API
  rescue_from StandardError do |exception|
    unless Rails.env.development?
      render json: {data: nil, error: "Internal server error"}, status: :internal_server_error
      break
    end

    render json: {data: nil, error: exception.message}, status: :internal_server_error
  end
end
