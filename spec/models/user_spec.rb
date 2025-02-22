# frozen_string_literal: true

RSpec.describe User, type: :model do
  it 'can be created' do
    user = User.create(name: 'John Doe')

    expect(user).to be_valid
  end

  it 'is not created without a name' do
    user = User.create(name: nil)

    expect(user.errors[:name]).to include("can't be blank")
  end
end
