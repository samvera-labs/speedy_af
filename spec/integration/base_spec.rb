require 'spec_helper'
require 'rdf/vocab/dc'

describe SpeedyAF::Base do
  before { load_fixture_classes!   }
  after  { unload_fixture_classes! }

  let!(:library) { Library.create }
  let!(:book) { Book.new title: 'Ordered Things', publisher: 'ActiveFedora Performance LLC', library: library }
  let!(:chapters) {[
    Chapter.create(title: 'Chapter 3', contributor: ['Hopper', 'Lovelace', 'Johnson']),
    Chapter.create(title: 'Chapter 1', contributor: ['Rogers', 'Johnson', 'Stark', 'Romanoff']),
    Chapter.create(title: 'Chapter 2', contributor: ['Alice', 'Bob', 'Charlie'])
  ]}
  let!(:indexed_content) {
    <<-IPSUM
    Zombie ipsum reversus ab viral inferno, nam rick grimes malum cerebro. De carne lumbering
    animata corpora quaeritis. Summus brains sit, morbo vel maleficia? De apocalypsi gorger
    omero undead survivor dictum mauris. Hi mindless mortuis soulless creaturas, imo evil
    stalking monstra adventus resi dentevil vultus comedat cerebella viventium.
    IPSUM
  }
  let!(:unindexed_content) {
    <<-IPSUM
    Qui animated corpse, cricket bat max brucks terribilem incessu zomby. The voodoo sacerdos
    flesh eater, suscitat mortuos comedere carnem virus. Zonbi tattered for solum oculi eorum
    defunctis go lum cerebro. Nescio brains an Undead zombies. Sicut malus putrid voodoo horror.
    Nigh tofth eliv ingdead.
    IPSUM
  }
  let(:book_presenter) { described_class.find(book.id) }

  context 'lightweight presenter' do
    before do
      book.indexed_file.content = indexed_content
      book.unindexed_file.content = unindexed_content
      book.chapters = chapters
      book.ordered_chapters = chapters.sort_by(&:title)
      book.save!
    end

    it '#respond_to?' do
      expect(book_presenter).to respond_to(:title)
      expect(book_presenter).to respond_to(:chapters)
      expect(book_presenter).to respond_to(:indexed_file)
      expect(book_presenter).to respond_to(:unindexed_file)
      expect { book_presenter.fthagn }.to raise_error(NoMethodError)
    end

    it '.find' do
      expect(book_presenter).to be_a(described_class)
      expect(book_presenter.publisher).to eq(book.publisher)
    end

    it '.where' do
      chapter_presenter = described_class.where('contributor_tesim:"Johnson"')
      expect(chapter_presenter.length).to eq(2)
    end

    it '.to_query' do
      expect(book.to_query('book_id')).to eq("book_id=#{URI.encode(book.id,/[^\-_.!~*'()a-zA-Z\d;?:@&=+$,\[\]]/)}")
    end

    context 'reflections' do
      let!(:library_presenter) { described_class.find(library.id) }

      it 'loads via indexed proxies' do
        expect(book_presenter.chapter_ids).to match_array(book.chapter_ids)
      end

      it 'loads indexed targets' do
        expect(book_presenter.ordered_chapter_ids).to eq(book.ordered_chapter_ids)
        chapter_presenters = book_presenter.ordered_chapters
        expect(chapter_presenters.length).to eq(chapters.length)
        expect(chapter_presenters.all? { |cp| cp.is_a?(described_class) }).to be_truthy
        expect(chapter_presenters.collect(&:title)).to eq(book.ordered_chapters.to_a.collect(&:title))
        expect(book_presenter).not_to be_real
      end

      it 'loads indexed subresources' do
        ipsum_presenter = book_presenter.indexed_file
        expect(ipsum_presenter.model).to eq(IndexedFile)
        expect(ipsum_presenter.content).to eq(indexed_content)
        expect(book_presenter).not_to be_real
        expect(ipsum_presenter).not_to be_real
      end

      it 'loads has_many reflections' do
        library.books.create(title: 'Ordered Things II')
        library.save
        presenter = library_presenter.books
        expect(presenter.length).to eq(2)
        expect(presenter.all? { |bp| bp.is_a?(described_class) }).to be_truthy
        expect(library_presenter.book_ids).to match_array(library.book_ids)
        expect(library_presenter).not_to be_real
      end

      it 'loads belongs_to reflections' do
        expect(book_presenter.library_id).to eq(library.id)
        expect(book_presenter.library).to be_a(described_class)
        expect(book_presenter.library.model).to eq(library.class)
        expect(book_presenter).not_to be_real
      end
    end

    context 'configuration' do
      before do
        described_class.config Book do
          include DowncaseBehavior
          self.defaults = { foo: 'bar!' }
        end

        described_class.config SpeedySpecs::DeepClass do
          self.defaults = { baz: 'quux!' }
        end
      end

      it 'adds default values' do
        expect(book_presenter.foo).to eq('bar!')
      end

      it 'mixes in the mixins' do
        expect(book_presenter.lowercase_title).to eq(book.lowercase_title)
        expect(book_presenter).not_to be_real
      end

      it 'works with nested classes' do
        expect(described_class.proxy_class_for(SpeedySpecs::DeepClass)).to eq(SpeedyAF::Proxy::SpeedySpecs::DeepClass)
      end
    end

    context 'reification' do
      it 'knows when it is real' do
        expect(book_presenter).not_to be_real
        expect(book_presenter.real_object).to be_a(Book)
        expect(book_presenter).to be_real
      end

      it '#reload (Base)' do
        expect(book_presenter.real_object).to be_a(Book)
        book_presenter.reload
        expect(book_presenter).not_to be_real
      end

      it '#reload (File)' do
        ipsum_presenter = book_presenter.indexed_file
        expect(ipsum_presenter.real_object).to be_a(IndexedFile)
        ipsum_presenter.reload
        expect(ipsum_presenter).not_to be_real
      end

      it 'reifies when it has to' do
        expect(book_presenter.uppercase_title).to eq(book.title.upcase)
        expect(book_presenter).to be_real
      end

      it 'reifies indexed subresources' do
        ipsum_presenter = book_presenter.indexed_file
        expect(ipsum_presenter.metadata).to be_a(ActiveFedora::WithMetadata::MetadataNode)
        expect(ipsum_presenter).to be_real
      end

      it 'loads unindexed subresources' do
        expect(book_presenter.unindexed_file.content).to eq(unindexed_content)
        expect(book_presenter).to be_real
      end
    end
  end
end
