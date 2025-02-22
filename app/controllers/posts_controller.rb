# frozen_string_literal: true

# rbs_inline: enabled

class PostsController < ApplicationController
  def show
    post = Post.find_by(id: params[:id])

    if post.present?
      render json: { data: post, error: nil }, status: :ok
    else
      render json: { data: nil, error: 'Post not found' }, status: :not_found
    end
  end

  def create
    author = User.find_by(id: author_params[:id])
    if author.blank?
      render json: { data: nil, error: 'Author not found' }, status: :not_found
      return
    end

    post = Post.new(post_params)
    post.user = author

    if post.save
      render json: { data: post, error: nil }, status: :created
    else
      render json: { data: nil, error: post.errors }, status: :unprocessable_content
    end
  end

  def update
    post = Post.find_by(id: params[:id])

    if post.blank?
      render json: { data: nil, error: 'Post not found' }, status: :not_found
      return
    end

    if post.update(post_params)
      render json: { data: post, error: nil }, status: :ok
    else
      render json: { data: nil, error: post.errors }, status: :unprocessable_content
    end
  end

  def destroy
    post = Post.find_by(id: params[:id])

    if post.blank?
      render json: { data: nil, error: 'Post not found' }, status: :not_found
      return
    end

    if post.destroy
      render json: { data: "Post with id #{params[:id]} has been deleted", error: nil }, status: :ok
    else
      render json: { data: nil, error: post.errors }, status: :unprocessable_content
    end
  end

  private

  # @rbs () -> { title: String?, content: String? }
  def post_params
    params.expect(post: %i[title content])
  end

  # @rbs () -> { id: Integer? }
  def author_params
    params.expect(user: [:id])
  end
end
