require 'spec_helper'

describe ActiveFedora::Performance::OrderedAggregationIndex do
  before { load_fixture_classes!   }
  after  { unload_fixture_classes! }

  describe 'method injection' do
    subject(:book) { Book.new }

    it 'respond to index methods' do
      expect(book).to respond_to(:indexed_chapter_ids)
      expect(book).to respond_to(:indexed_chapters)
    end
  end

  describe 'indexing' do
    subject(:book) { Book.new }

    it 'empty' do
      expect(book.indexed_chapter_ids).to be_empty
    end

    context 'with chapters' do
      let!(:chapters) { 1.upto(5).map { Chapter.create } }

      before do
        book.ordered_chapters = chapters.reverse
        book.save
      end

      it 'loads indexed chapter IDs' do
        expect(book.indexed_chapter_ids).to eq(book.ordered_chapter_ids)
      end

      it 'loads indexed chapters' do
        expect(book.indexed_chapters.to_a).to eq(book.ordered_chapters.to_a)
      end
    end
  end
end
