# frozen_string_literal: true

RSpec.describe IdempotentRequest, type: :model do
  describe "有効期限内の同一リクエストに対する uniqueness" do
    subject do
      IdempotentRequest.new(key: uuid, request_method: request_method, request_path: request_path,
        request_params: request_params)
    end

    let!(:uuid) { "3f47bbb2-aaa4-472d-be4a-7a555787a204" }
    let!(:request_method) { "POST" }
    let!(:request_path) { "/graphql" }
    let!(:request_params) { {foo: "bar"} }

    context "同一リクエストが存在しない場合" do
      it { is_expected.to be_valid }
    end

    context "同一リクエストが存在する場合" do
      before do
        create(:idempotent_request, key: uuid, request_method: request_method, request_path: request_path)
      end

      it { is_expected.to be_invalid }
    end

    context "同一リクエストが存在し、現在時刻が有効な境界値の場合" do
      before do
        create(:idempotent_request, key: uuid, request_method: request_method, request_path: request_path)
        travel_to(24.hours.from_now)
      end

      it { is_expected.to be_invalid }
    end

    context "同一リクエストが存在しても有効期限が切れている場合" do
      before do
        create(:idempotent_request, key: uuid, request_method: request_method, request_path: request_path)
        travel_to((24.hours + 1.second).from_now)
      end

      it { is_expected.to be_valid }
    end
  end

  describe "alive? と alive scope の挙動およびその一貫性" do
    let!(:idempotency_key) { create(:idempotent_request) }

    context "有効期限内の場合" do
      it "alive? は true を返すこと" do
        expect(idempotency_key).to be_alive
      end

      it "alive scope に含まれること" do
        expect(IdempotentRequest.alive).to include idempotency_key
      end
    end

    context "有効な境界値の場合" do
      before { travel_to(24.hours.from_now) }

      it "alive? は true を返すこと" do
        expect(idempotency_key).to be_alive
      end

      it "alive scope に含まれること" do
        expect(IdempotentRequest.alive).to include idempotency_key
      end
    end

    context "有効期限が切れている場合" do
      before { travel_to((24.hours + 1.second).from_now) }

      it "alive? は false を返すこと" do
        expect(idempotency_key).not_to be_alive
      end

      it "alive scope に含まれないこと" do
        expect(IdempotentRequest.alive).not_to include idempotency_key
      end
    end
  end

  describe "find_alive_by_request" do
    subject(:found_key) do
      IdempotentRequest.find_alive_by_request(idempotency_key: uuid, method: request_method, path: request_path)
    end

    let!(:uuid) { "3f47bbb2-aaa4-472d-be4a-7a555787a204" }
    let!(:request_method) { "POST" }
    let!(:request_path) { "/graphql" }

    let!(:existing_key) do
      create(:idempotent_request, key: "3f47bbb2-aaa4-472d-be4a-7a555787a204", request_method: "POST",
        request_path: "/graphql")
    end

    context "key, method, path が全て等しい場合" do
      it "キーは見つかる" do
        expect(found_key).to eq existing_key
      end
    end

    context "key が異なる場合" do
      let(:uuid) { SecureRandom.uuid_v4 }

      it "キーは見つからない" do
        expect(found_key).to be_nil
      end
    end

    context "method が異なる場合" do
      let(:request_method) { "GET" }

      it "キーは見つからない" do
        expect(found_key).to be_nil
      end
    end

    context "path が異なる場合" do
      let(:request_path) { "/test" }

      it "キーは見つからない" do
        expect(found_key).to be_nil
      end
    end

    context "有効な境界値の場合" do
      it "キーは見つかる" do
        travel_to(24.hours.from_now)
        expect(found_key).to eq existing_key
      end
    end

    context "有効期限が切れたキーを検索しようとした場合" do
      it "キーは見つからない" do
        travel_to((24.hours + 1.second).from_now)
        expect(found_key).to be_nil
      end
    end
  end

  describe "#with_idempotent_lock!" do
    let!(:idempotency_key) { create(:idempotent_request) }

    it "ブロックを実行しブロックの戻り値を最終的な戻り値とすること" do
      result = idempotency_key.with_idempotent_lock! { "result" }
      expect(result).to eq "result"
    end

    it "ブロックには IdempotentRequest インスタンスが渡されること" do
      idempotency_key.with_idempotent_lock! do |key|
        expect(key).to eq idempotency_key
      end
    end

    describe "ロックの挙動" do
      it "ブロックが渡されなかった場合はロックに関する操作をまったく行わないこと" do
        allow(idempotency_key).to receive(:idempotent_lock!)
        allow(idempotency_key).to receive(:idempotent_unlock!)
        idempotency_key.with_idempotent_lock!

        aggregate_failures do
          expect(idempotency_key).not_to have_received(:idempotent_lock!)
          expect(idempotency_key).not_to have_received(:idempotent_unlock!)
        end
      end

      it "ブロックの実行前に必ずロックを取り、ブロックの実行後に必ずロックを解除すること" do
        aggregate_failures do
          idempotency_key.with_idempotent_lock! do |current_key|
            expect(current_key.locked?).to be true
          end

          expect(idempotency_key.locked?).to be false
        end
      end

      it "ブロックの中でさらにロックを取ろうとすると AlreadyLocked が発生すること" do
        expect do
          idempotency_key.with_idempotent_lock! do |current_key|
            current_key.with_idempotent_lock! { "2nd Lock" }
          end
        end.to raise_error(IdempotentRequest::Error::AlreadyLocked)
      end

      it "ブロックの処理が異常終了しても必ずロックを解除すること" do
        aggregate_failures do
          expect do
            idempotency_key.with_idempotent_lock! { raise "Error" }
          end.to raise_error("Error")

          expect(idempotency_key.locked?).to be false
        end
      end

      it "既にロックされているキーに対して実行した場合は例外を発生させること" do
        idempotency_key.update(locked_at: Time.current)

        expect do
          idempotency_key.with_idempotent_lock! { "result" }
        end.to raise_error(IdempotentRequest::Error::AlreadyLocked)
      end
    end
  end

  describe "#set_response!" do
    let!(:idempotency_key) { create(:idempotent_request) }
    let(:body) { "result" }
    let(:status) { 200 }
    let(:headers) { {"Content-Type" => "application/json"} }

    context "response_body, response_code, response_headers を指定した場合" do
      subject(:complete_request) do
        idempotency_key.set_response!(body: body, status: status, headers: headers)
      end

      it "レスポンスのデータが更新されること" do
        complete_request

        aggregate_failures do
          expect(idempotency_key.response_body).to eq body
          expect(idempotency_key.response_code).to eq status
          expect(idempotency_key.response_headers).to eq headers
        end
      end
    end

    context "response_headers を指定しない場合" do
      subject(:complete_request) do
        idempotency_key.set_response!(body: body, status: status)
      end

      it "headers は空のハッシュとして記録されること" do
        complete_request

        aggregate_failures do
          expect(idempotency_key.response_body).to eq body
          expect(idempotency_key.response_code).to eq status
          expect(idempotency_key.response_headers).to eq({})
        end
      end
    end
  end

  describe "#same_payload?" do
    subject do
      idempotency_key.same_payload?(method: request_method, path: request_path, params: request_params.to_unsafe_h)
    end

    let(:request_method) { "POST" }
    let(:request_path) { "/graphql" }
    let(:request_params) { ActionController::Parameters.new({foo: "bar"}) }

    let!(:idempotency_key) do
      create(:idempotent_request, request_path: "/graphql", request_method: "POST", request_params: {foo: "bar"})
    end

    context "リクエストの情報が全て等しい場合" do
      it { is_expected.to be true }
    end

    context "リクエストの method が異なる場合" do
      let(:request_method) { "GET" }

      it { is_expected.to be false }
    end

    context "リクエストの path が異なる場合" do
      let(:request_path) { "/test" }

      it { is_expected.to be false }
    end

    context "リクエストの params が異なる場合" do
      let(:request_params) { ActionController::Parameters.new({foo: "baz"}) }

      it { is_expected.to be false }
    end
  end

  describe "#locked?" do
    subject { idempotency_key.locked? }

    let!(:idempotency_key) { create(:idempotent_request) }

    context "ロックされている場合" do
      before { idempotency_key.update(locked_at: Time.current) }

      it { is_expected.to be true }
    end

    context "ロックされていない場合" do
      before { idempotency_key.update(locked_at: nil) }

      it { is_expected.to be false }
    end
  end

  describe  "#response_available?" do
    subject { idempotency_key.response_available? }

    let!(:idempotency_key) { create(:idempotent_request) }
    let(:response_body) { "" }
    let(:response_code) { 0 }
    let(:response_headers) { {} }

    before do
      idempotency_key.update(response_body: response_body, response_code: response_code,
        response_headers: response_headers)
    end

    context "response_body と response_code が設定されている場合" do
      let(:response_body) { "result" }
      let(:response_code) { 200 }

      it { is_expected.to be true }
    end

    context "response_body が設定されていない場合" do
      let(:response_code) { 200 }

      it { is_expected.to be false }
    end

    context "response_code が設定されていない場合" do
      let(:response_body) { "result" }

      it { is_expected.to be false }
    end

    context "response_header が {} の場合" do
      let(:response_body) { "result" }
      let(:response_code) { 200 }
      let(:response_headers) { {} }

      it { is_expected.to be true }
    end
  end
end
