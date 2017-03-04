require 'spec_helper'
require 'rdf/vocab/dc'

describe ActiveFedora::Performance::SolrPresenter do
  before { load_fixture_classes!   }
  after  { unload_fixture_classes! }

  subject(:book) { Book.new title: 'Ordered Things', publisher: 'ActiveFedora Performance LLC' }
  let!(:chapters) {[
    Chapter.create(title: 'Chapter 3', contributors: ['Hopper', 'Lovelace', 'Johnson']),
    Chapter.create(title: 'Chapter 1', contributors: ['Rogers', 'Johnson', 'Stark', 'Romanoff']),
    Chapter.create(title: 'Chapter 2', contributors: ['Alice', 'Bob', 'Charlie'])
  ]}
  
  context 'lightweight presenter' do
    before do
      book.chapters = chapters
      book.ordered_chapters = chapters.sort_by(&:title)
      book.save!
    end
    
    it 'find' do
      book_presenter = ActiveFedora::Performance::SolrPresenter.find(book.id)
      expect(book_presenter).to be
    end
    
    it 'where' do
      
    end
  end
end
