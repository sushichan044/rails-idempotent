# frozen_string_literal: true

# frozen_string_literal: true

describe UuidValidator do
  describe '#validate_each' do
    context 'without version specified' do
      let(:klass) do
        Struct.new(:value) do
          include ActiveModel::Validations

          validates :value, uuid: true

          def self.name
            'Klass'
          end
        end
      end

      it 'is valid if value is a valid UUID' do
        value = SecureRandom.uuid_v7
        instance = klass.new(value)

        expect(instance).to be_valid
      end

      it 'is valid if value is nil' do
        value = nil
        instance = klass.new(value)

        expect(instance).to be_valid
      end

      it 'is invalid if value is not a valid UUID' do
        value = 'invalid-uuid'
        instance = klass.new(value)
        expect(instance).to be_invalid
      end
    end

    context 'with version specified' do
      let(:klass) do
        Struct.new(:value) do
          include ActiveModel::Validations

          validates :value, uuid: { version: 4 }

          def self.name
            'Klass'
          end
        end
      end

      it 'is valid if value is a valid UUID of the specified version' do
        value = SecureRandom.uuid_v4
        instance = klass.new(value)
        expect(instance).to be_valid
      end

      it 'is invalid if value is a valid UUID of a different version' do
        value = SecureRandom.uuid_v7
        instance = klass.new(value)
        expect(instance).to be_invalid
      end
    end
  end
end
