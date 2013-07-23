desc "Import content from static auroville.org site"
task :import_content => :environment do
  require 'rubygems'
  require 'nokogiri' # for parsing html files from static site
  require 'open-uri' # allow remote urls
  require 'sanitize' # cleanup html

  require 'tasks/import/import' # import helper class

  base_path = '/Users/shankar/Dev/Auroville.org/auroville'

  Dir.glob("#{base_path}/**/*.htm*") do |path|
    import_content = Import.new(base_path, path)
    path.force_encoding('binary')
    legacy_path = path.sub(base_path, '')
      c = Content.where(:legacy_path => legacy_path).first
      time = File.mtime(path)
      if c.blank?
        c = Content.new
        c.legacy_path = legacy_path
      end
      c.title = import_content.title
      c.body = import_content.body
      c.image_assets << import_content.ref_images
      c.file_assets << import_content.ref_files
      c.old_categories << import_content.category 
      c.migration_status = 'Imported'
      c.created_at = time
      c.updated_at = time
      c.save
  end
  
end