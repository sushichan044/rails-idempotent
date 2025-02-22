# frozen_string_literal: true

RSpec.describe Post, type: :model do
  context 'with existing author' do
    let!(:author) { create(:user) }

    it 'can be created' do
      post = Post.create(title: 'Title', content: 'Content', user: author)

      expect(post).to be_valid
    end

    context 'with invalid attributes' do
      it 'cannot be created without a title' do
        post = Post.create(content: 'Content', title: '', user: author)

        expect(post.errors[:title]).to include("can't be blank")
      end

      it 'cannot be created without content' do
        post = Post.create(content: '', title: 'Title', user: author)

        expect(post.errors[:content]).to include("can't be blank")
      end
    end
  end
end
