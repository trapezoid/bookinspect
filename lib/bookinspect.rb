require 'pdf-reader'
require 'zbar'
require 'amazon/ecs'
require 'tempfile'
require 'rmagick'
include Magick

class BookInfo
  attr_reader :page_num, :isbn, :items
  def initialize page_num, isbn, items
    @page_num = page_num
    @isbn = isbn
    @items = items
  end
end

class PDFImages
  PDFIMAGES = '/usr/local/bin/pdfimages'

  def initialize file
    @file = file
  end

  def to_jpg first_page, last_page
    count = last_page - first_page + 1
    Dir.mktmpdir do |dir|
      system(PDFIMAGES, '-f', first_page.to_s, '-l', last_page.to_s, '-j', @file, "#{dir}/page")
      Dir.glob("#{dir}/page*").each do |page|
        yield page
      end
    end
  end
end

class BookInspect
  VERSION = "1.0"
  DENSITY = 200
  QUALITY = 100

  def initialize(config)
    Amazon::Ecs.configure do |options|
      options[:associate_tag] = config[:associate_tag]
      options[:AWS_access_key_id] = config[:AWS_access_key_id]
      options[:AWS_secret_key] = config[:AWS_secret_key]
    end
  end

  def from_pdf_by_pdfimages()
  end

  def from_pdf(file, first_check_pages, last_check_pages)
    result = nil
    isbn = nil
    pdf_reader = PDF::Reader.new file
    max_page_num = pdf_reader.page_count
    pdfimage = PDFImages.new(file)
    [[1, first_check_pages], [max_page_num - last_check_pages, max_page_num]].each do |s, e|
      pdfimage.to_jpg(s, e) do |page|
        page_image = Magick::Image.read(page).shift
        page_image.strip!
        [90, 90, 90].each do |degree|
          rotated_page_image = page_image.rotate!(degree)
          _scan_barcode_from_image(rotated_page_image).each do |code|
            if (code.symbology.to_s == "EAN-13") and (code.data.to_s.start_with? "978") then
              result = _get_iteminfo_from_isbn(code.data)
              isbn = code.data
            end
          end
          break if result != nil
        end
        break if result != nil
      end
      break if result != nil
    end

    return nil if result == nil
    return BookInfo.new(max_page_num, isbn, result)
  end

  def _read_image_from_pdf(file, page)
    images = Magick::Image.read("#{file}[#{page}]") do
      self.density = DENSITY
      self.quality = QUALITY
    end
    return images
  end

  def _scan_barcode_from_image(image)
    blob = image.to_blob do
      self.quality = 100
      #self.monochrome = true
      self.depth = 8
      self.format = 'PGM'
    end
    #puts blob
    pgm_image = ZBar::Image.from_pgm(blob)

    return pgm_image.process
  end

  def _get_iteminfo_from_isbn(isbn)
    res = Amazon::Ecs.item_search(
        isbn,
        {:search_index => 'Books',
         :response_group => 'Medium',
         :country => 'jp'})
    return res.items
  end
end
