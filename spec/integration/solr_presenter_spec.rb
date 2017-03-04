require 'spec_helper'
require 'rdf/vocab/dc'

describe ActiveFedora::Performance::SolrPresenter do
  before { load_fixture_classes!   }
  after  { unload_fixture_classes! }

  subject(:book) { Book.new title: 'Ordered Things', publisher: 'ActiveFedora Performance LLC' }
  let!(:chapters) {[
    Chapter.create(title: 'Chapter 3', contributor: ['Hopper', 'Lovelace', 'Johnson']),
    Chapter.create(title: 'Chapter 1', contributor: ['Rogers', 'Johnson', 'Stark', 'Romanoff']),
    Chapter.create(title: 'Chapter 2', contributor: ['Alice', 'Bob', 'Charlie'])
  ]}

  context 'lightweight presenter' do
    before do
      book.chapters = chapters
      book.ordered_chapters = chapters.sort_by(&:title)
      book.save!
    end

    it 'find' do
      book_presenter = described_class.find(book.id)
      expect(book_presenter).to be
      expect(book_presenter.publisher).to eq(book.publisher)
    end

    it 'where' do
      chapter_presenter = described_class.where('contributor_tesim:"Johnson"')
      expect(chapter_presenter.length).to eq(2)
    end
  end
end
