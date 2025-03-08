# frozen_string_literal: true

RSpec.describe "Posts", type: :request do
  describe "POST /posts" do
    context "with valid author" do
      let!(:author) { create(:user) }

      it "creates a new Post and returns it with valid parameters" do
        params = {post: {title: "Title", content: "Content"}, user: {id: author.id}}

        aggregate_failures do
          expect { post posts_path, params: params }.to change(Post, :count).by(1)
          expect(response.parsed_body["data"]).to eq Post.last.as_json
        end
      end

      it "returns an unprocessable entity status with invalid parameters" do
        params = {post: {title: "", content: nil}, user: {id: author.id}}

        aggregate_failures do
          expect { post posts_path, params: params }.not_to change(Post, :count)
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    it "cannot be created without valid author" do
      create(:user, id: 1)
      params = {post: {title: "Title", content: "Content"}, user: {id: 20_000}}

      aggregate_failures do
        expect { post posts_path, params: params }.not_to change(Post, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /posts/:id" do
    let!(:author) { create(:user) }

    it "returns a post with valid id" do
      post = create(:post, user: author)
      get post_path(post.id)

      expect(response.parsed_body["data"]).to eq post.as_json
    end

    it "returns a not found status with invalid id" do
      create(:post, id: 1, user: author)
      get post_path(-20_000)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT /posts/:id" do
    let!(:author) { create(:user) }

    it "updates a post with valid id" do
      post = create(:post, title: "Title", content: "Content", user: author)
      params = {post: {title: "New Title", content: "New Content"}}

      aggregate_failures do
        expect do
          put post_path(post.id), params: params
        end.to change {
          post.reload.title
        }.from("Title").to("New Title")
        expect(response.parsed_body["data"]).to eq post.reload.as_json
      end
    end

    it "returns a not found and do nothing with invalid id" do
      post = create(:post, id: 1, user: author)
      params = {post: {title: "New Title", content: "New Content"}}

      aggregate_failures do
        expect do
          put post_path(-20_000), params: params
        end.not_to(change { post.reload.title })
        expect(response).to have_http_status(:not_found)
      end
    end

    it "does not accept user parameter and does not update the author" do
      post = create(:post, user: author)

      illegal_author = create(:user)
      params = {post: {user: illegal_author}}

      aggregate_failures do
        expect do
          put post_path(post.id), params: params
        end.not_to(change { post.reload.user })
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "DELETE /posts/:id" do
    let!(:author) { create(:user) }

    it "deletes a post with valid id" do
      post = create(:post, user: author)
      delete post_path(post.id)

      expect(response.parsed_body["data"]).to eq "Post with id #{post.id} has been deleted"
    end

    it "returns a not found status with invalid id" do
      create(:post, id: 1, user: author)
      delete post_path(-20_000)

      expect(response).to have_http_status(:not_found)
    end
  end
end
