# frozen_string_literal: true

RSpec.describe "IdempotencyHelpers", type: :request do
  describe "リクエストの冪等性" do
    before do
      stub_const("MockController", Class.new(ApplicationController) do
        include IdempotencyHelpers

        def create # rubocop:disable Metrics/AbcSize
          header_key = request.headers["HTTP_IDEMPOTENCY_KEY"]

          response = ensure_request_idempotency!(
            key: header_key, method: request.request_method, path: request.path, params: params.to_unsafe_h
          ) do |key|
            user = User.create!(name: user_params)
            key.set_response!(body: user.to_json, status: 201)
          end
          render json: JSON.parse(response.body), status: response.status, headers: response.headers
        end

        private

        def user_params
          params.require(:user).permit(:name)
        end
      end)

      Rails.application.routes.draw { post "/", to: "mock#create" }
    end

    after do
      Rails.application.reload_routes!
    end

    context "無効な Idempotency-Key を指定した場合" do
      subject(:first_request) do
        post "/", params: {user: {name: "John Doe"}},
          headers: {"Idempotency-Key" => "019536e5-df1c-7f13-886f-bdb6fbf2e97a"} # UUID v7
      end

      it "IdempotencyError::InvalidKey が発生する" do
        expect { first_request }.to raise_error(IdempotencyHelpers::Errors::InvalidKey)
      end
    end

    context "未処理の Idempotency-Key を指定した場合" do
      subject(:first_request) do
        post "/", params: {user: {name: "John Doe"}}, headers: {"Idempotency-Key" => SecureRandom.uuid_v4}
      end

      it "新しいリクエストとして処理される" do
        expect { first_request }.to change(IdempotentRequest, :count).from(0).to(1)
      end
    end

    context "一度処理に失敗した Idempotency-Key を指定した場合" do
      subject(:retried_request) do
        post "/", params: request_params, headers: {"Idempotency-Key" => idempotency_key_header}
        {body: response.body, status: response.status}
      end

      let!(:idempotency_key_header) { SecureRandom.uuid_v4 }
      let!(:request_params) { {user: {name: "John Doe"}} }

      before do
        # 一度目のリクエストで DB への接続がタイムアウトし、ActiveRecord::ConnectionTimeoutError が発生したので Controller の処理が中断されているとする
        post "/", params: request_params, headers: {"Idempotency-Key" => idempotency_key_header}
        # 擬似的に処理に失敗した状態を作る
        # 処理に失敗して中断されたならレスポンス情報は格納されていない
        IdempotentRequest.find_by!(key: idempotency_key_header).update!(response_body: "", response_code: 0)
        # 処理に失敗しているなら User は作成されていない
        User.last.destroy!
      end

      it "既存の Idempotency-Key に紐づくリクエストの処理を再開する" do
        RSpec::Matchers.define_negated_matcher :not_change, :change

        aggregate_failures do
          expect { retried_request }.to not_change(IdempotentRequest, :count).and change(User, :count).from(0).to(1)
          expect(retried_request[:status]).to eq(201)
        end
      end
    end

    context "既に処理済みで有効期限が切れた Idempotency-Key を指定した場合" do
      subject(:first_request) do
        post "/", params: {user: {name: "John Doe"}}, headers: {"Idempotency-Key" => idempotency_key_header}
      end

      let!(:idempotency_key_header) { SecureRandom.uuid_v4 }

      before do
        post "/", params: {user: {name: "John Doe"}}, headers: {"Idempotency-Key" => idempotency_key_header}
        travel_to((24.hours + 1.second).from_now)
      end

      it "運悪く期限切れの Key のぶつかったというエラーを返す" do
        expect { first_request }.to raise_error(IdempotencyHelpers::Errors::KeyIsStale)
      end
    end

    context "既に処理済みで alive な Idempotency-Key を指定した場合" do
      subject(:second_response) do
        post "/", params: request_params, headers: {"Idempotency-Key" => idempotency_key_header}
        {body: response.body, status: response.status}
      end

      let(:request_params) { {user: {name: "John Doe"}} }
      let!(:idempotency_key_header) { SecureRandom.uuid_v4 }
      let!(:first_response) do
        post "/", params: {user: {name: "John Doe"}}, headers: {"Idempotency-Key" => idempotency_key_header}
        {body: response.body, status: response.status}
      end

      context "リクエストパラメータが一致する場合" do # rubocop:disable RSpec/NestedGroups
        it "既存のレスポンスを返す" do
          aggregate_failures do
            expect { second_response }.not_to change(IdempotentRequest, :count)
            expect(second_response[:body]).to eq(first_response[:body])
            expect(second_response[:status]).to eq(first_response[:status])
          end
        end
      end

      context "リクエストパラメータが一致しない場合" do # rubocop:disable RSpec/NestedGroups
        let(:request_params) { {user: {name: "INVALID"}} }

        it "IdempotencyError::RequestMismatch が発生する" do
          expect { second_response }.to raise_error(IdempotencyHelpers::Errors::RequestMismatch)
        end
      end

      context "前のリクエストが処理中の場合" do # rubocop:disable RSpec/NestedGroups
        before do
          # 擬似的に処理中の状態を作る
          IdempotentRequest.find_by(key: idempotency_key_header)
            .update!(locked_at: Time.current, response_code: 0, response_body: "")
        end

        it "IdempotencyError::KeyLocked が発生する" do
          expect { second_response }.to raise_error(IdempotencyHelpers::Errors::KeyLocked)
        end
      end
    end
  end

  describe "冪等処理のブロックの使い方" do
    before do
      stub_const("MockController", Class.new(ApplicationController) do
        include IdempotencyHelpers

        def create # rubocop:disable Metrics/AbcSize
          header_key = request.headers["HTTP_IDEMPOTENCY_KEY"]

          response = ensure_request_idempotency!(
            key: header_key, method: request.request_method, path: request.path, params: params.to_unsafe_h
          ) { User.create!(name: user_params) }

          render json: JSON.parse(response.body), status: response.status, headers: response.headers
        end

        private

        def user_params
          params.require(:user).permit(:name)
        end
      end)

      Rails.application.routes.draw { post "/", to: "mock#create" }
    end

    after do
      Rails.application.reload_routes!
    end

    context "with_idempotent_request! に渡したブロック内でレスポンス情報を格納しない場合" do
      subject(:request) do
        post "/", params: {user: {name: "John Doe"}}, headers: {"Idempotency-Key" => SecureRandom.uuid_v4}
      end

      it "IdempotencyError::ResponseNotSet が発生する" do
        expect { request }.to raise_error(IdempotencyHelpers::Errors::ResponseNotSet)
      end
    end
  end
end
