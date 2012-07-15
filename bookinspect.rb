#!/usr/bin/env ruby
# coding: utf-8

require 'rubygems'
require 'commander/import'
require 'pit'

require File.expand_path("lib/bookinspect.rb", File.dirname(__FILE__))

config = Pit.get("amazon-ecs", {:require => {
  :associate_tag => "please input yor associate tag",
  :AWS_access_key_id => "please input your aws access key id",
  :AWS_secret_key => "please input your aws secret key"
}})

program :version, "1.00"
program :description, 'Rename pdf from barcode'

command :detect do |c|
  c.syntax = 'bookinspect detect [options]'
  c.summary = ''
  c.description = ''
  c.example 'description', 'command example'
  c.option '--head FIXNUM', String, 'Fetch page num from head'
  c.option '--tail FIXNUM', String, 'Fetch page num from tail'
  c.action do |args, options|
    options.default :head => '5', :tail => '2'

    args.each do |file|
      next unless File.exist? file

      bi = BookInspect.new(config)
      result = bi.from_pdf(file, options.head.to_i, options.tail.to_i)
      result.items.each do |item|
        puts item
        print "ASIN= ",     item.get('ASIN'), "\n"
        print "Title= ",    item.get('ItemAttributes/Title'), "\n"
        print "Author= ",   item.get('ItemAttributes/Author'), "\n"
        print "PageNum= ",  result.page_num, "\n"
      end
    end
    # Do something or c.when_called Bookinspect::Commands::Detect
  end
end

command :rename do |c|
  c.syntax = 'bookinspect detect [options]'
  c.summary = ''
  c.description = ''
  c.example 'description', 'command example'
  c.option '--format STRING', String, 'Filename format'
  c.option '--head FIXNUM', String, 'Fetch page num from head'
  c.option '--tail FIXNUM', String, 'Fetch page num from tail'
  c.action do |args, options|
    options.default :head => '5', :tail => '2', :format => ":title-(:author)-:page_nump_:isbn.pdf"

    args.each do |file|
      next unless File.exist? file

      bi = BookInspect.new(config)
      result = bi.from_pdf(file, options.head.to_i, options.tail.to_i)
      result.items.each do |item|
        asin = item.get('ASIN')
        isbn = item.get('ItemAttributes/ISBN')
        title = item.get('ItemAttributes/Title')
        author = item.get('ItemAttributes/Author')
        page_num = result.page_num

        name = options.format.to_s.dup

        replaces = {
            ":asin" => asin.to_s,
            ":isbn" => result.isbn.to_s,
            ":title" => title,
            ":author" => author != nil ? author : "その他",
            ":page_num" => page_num.to_s
        }

        puts replaces
        replaces.each do |key, value|
          name.gsub! key, value
        end

        FileUtils.move(file, File.join(File.dirname(file), name))
        puts file
        puts File.join(File.dirname(file), name)
        break
      end
    end
    # Do something or c.when_called Bookinspect::Commands::Detect
  end
end

