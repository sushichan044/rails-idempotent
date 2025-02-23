# frozen_string_literal: true

RSpec.describe IdempotencyKey, type: :model do
  let!(:idempotency_key) { create(:idempotency_key) }

  describe '#with_idempotent_lock' do
    it 'executes the block within the lock' do
      expect { |b| idempotency_key.with_idempotent_lock!(&b) }.to yield_control
    end

    it 'raises an error if already locked' do
      idempotency_key.update(locked_at: Time.current)

      expect do
        idempotency_key.with_idempotent_lock!
      end.to raise_error(IdempotencyKey::Error::AlreadyLocked)
    end

    it 'must lock before execution and unlock after execution' do
      aggregate_failures do
        idempotency_key.with_idempotent_lock! do
          expect(idempotency_key.locked?).to be true
        end

        expect(idempotency_key.locked?).to be false
      end
    end

    it 'must unlock when an exception is raised in the block' do
      aggregate_failures do
        expect do
          idempotency_key.with_idempotent_lock! { raise 'Error' }
        end.to raise_error('Error')

        expect(idempotency_key.locked?).to be false
      end
    end
  end

  describe '#expired?' do
    it 'returns true if expired' do
      idempotency_key.update(expired_at: 1.day.ago)
      expect(idempotency_key.expired?).to be true
    end

    it 'returns false if not expired' do
      idempotency_key.update(expired_at: 1.day.from_now)
      expect(idempotency_key.expired?).to be false
    end
  end

  describe '#locked?' do
    it 'returns true if locked' do
      idempotency_key.update(locked_at: Time.current)
      expect(idempotency_key.locked?).to be true
    end

    it 'returns false if not locked' do
      idempotency_key.update(locked_at: nil)
      expect(idempotency_key.locked?).to be false
    end
  end
end
