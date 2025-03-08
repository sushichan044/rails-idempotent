# frozen_string_literal: true

RSpec.describe "Users", type: :request do
  describe "POST /users" do
    let(:headers) { {"Idempotency-Key": SecureRandom.uuid_v4} }

    it "creates a new User and returns it with valid parameters" do
      aggregate_failures do
        expect do
          post users_path, params: {user: {name: "John Doe"}}, headers: headers
        end.to change(User, :count).by(1)
        expect(response.parsed_body["data"]).to eq User.last.as_json
      end
    end

    it "returns an unprocessable entity status with invalid name" do
      aggregate_failures do
        expect { post users_path, params: {user: {name: nil}}, headers: headers }.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /users/:id" do
    it "returns a user with valid id" do
      user = create(:user, name: "Joh")
      get user_path(user.id)

      expect(response.parsed_body["data"]).to eq user.as_json
    end

    it "returns a not found status with invalid id" do
      create(:user, id: 1)
      get user_path(-20_000)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT /users/:id" do
    it "updates a user with valid id" do
      user = create(:user, name: "John Doe")
      params = {user: {name: "I am superman"}}

      aggregate_failures do
        expect { put user_path(user.id), params: params }.to change {
          user.reload.name
        }.from("John Doe").to("I am superman")
        expect(response.parsed_body["data"]).to eq user.reload.as_json
      end
    end

    it "returns a not found and do nothing with invalid id" do
      user = create(:user, id: 1, name: "John Doe")
      params = {user: {name: "Banana Man"}}

      aggregate_failures do
        expect { put user_path(-20_000), params: params }.not_to(change { user.reload.name })
        expect(response).to have_http_status(:not_found)
      end
    end

    it "returns an unprocessable entity and do nothing with invalid name" do
      user = User.create(name: "John Doe")
      params = {user: {name: ""}}

      aggregate_failures do
        expect { put user_path(user.id), params: params }.not_to(change { user.reload.name })
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /users/:id" do
    it "deletes a user with valid id" do
      user = create(:user)

      aggregate_failures do
        expect { delete user_path(user.id) }.to change(User, :count).by(-1)
        expect(response.parsed_body).to include(data: "User with id #{user.id} has been deleted")
      end
    end

    it "returns a not found status with invalid id" do
      create(:user, id: 1)

      aggregate_failures do
        expect { delete user_path(-20_000) }.not_to change(User, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
