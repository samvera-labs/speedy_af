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
  let!(:ipsum) {
    <<-IPSUM
    Zombie ipsum reversus ab viral inferno, nam rick grimes malum cerebro. De carne lumbering
    animata corpora quaeritis. Summus brains sit​​, morbo vel maleficia? De apocalypsi gorger
    omero undead survivor dictum mauris. Hi mindless mortuis soulless creaturas, imo evil
    stalking monstra adventus resi dentevil vultus comedat cerebella viventium. Qui animated
    corpse, cricket bat max brucks terribilem incessu zomby. The voodoo sacerdos flesh eater,
    suscitat mortuos comedere carnem virus. Zonbi tattered for solum oculi eorum defunctis
    go lum cerebro. Nescio brains an Undead zombies. Sicut malus putrid voodoo horror. Nigh
    tofth eliv ingdead.
    IPSUM
  }
  let(:book_presenter) { described_class.find(book.id) }

  context 'lightweight presenter' do
    before do
      book.notes.content = ipsum
      book.chapters = chapters
      book.ordered_chapters = chapters.sort_by(&:title)
      book.save!
    end

    it 'respond_to?' do
      expect(book_presenter).to respond_to(:title)
      expect(book_presenter).to respond_to(:chapters)
      expect(book_presenter).to respond_to(:notes)
    end

    it 'find' do
      expect(book_presenter).to be_a(described_class)
      expect(book_presenter.publisher).to eq(book.publisher)
    end

    it 'where' do
      chapter_presenter = described_class.where('contributor_tesim:"Johnson"')
      expect(chapter_presenter.length).to eq(2)
    end

    context 'reflections' do
      it 'loads indexed targets' do
        chapter_presenters = book_presenter.ordered_chapters
        expect(chapter_presenters.length).to eq(chapters.length)
        expect(chapter_presenters.all? { |cp| cp.is_a?(described_class) }).to be_truthy
        expect(chapter_presenters.collect(&:title)).to eq(book.ordered_chapters.to_a.collect(&:title))
      end

      it 'loads indexed subresources' do
        ipsum_presenter = book_presenter.notes
        expect(ipsum_presenter).to be_a(IndexedFile)
        expect(ipsum_presenter.content).to eq(ipsum)
      end
    end

    context 'reification' do
      it 'reifies when it has to' do
        expect(book_presenter.uppercase_title).to eq(book.title.upcase)
      end
    end
  end
end
