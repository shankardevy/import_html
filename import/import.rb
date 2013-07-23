class Import

  def initialize(base_path, path)
    puts path
    @base_path = base_path
    @path = path
    @doc = Nokogiri::HTML(open(path))
    @title = ''  
    @body = ''
    @images = []
    @files = []
    @category = []
    @image_refs = []
    @file_refs = [] 
    @internal_links = []
    images()
    files()
  end

  # Gets the title of the html page using the content in <title> 
  def title
    @title = @doc.css("title").text
  end


  # Gets the old category based on second part of breadcrumbs defined in html
  def category
    @category = @doc.css(".path:first > a")[1].text rescue 'Uncategorized'
    @category = @category.split.join(" ")
    condition = {:name => @category}
    OldCategory.find_or_create_by_name(condition)
  end


  # Gets the path to various images referred in the current html
  # except .gif files 
  def images
    @doc.css('img').each do |img|
      src = img['src']
      unless src.include? ".gif"
        image = Hash.new
        image['href'] = src
        image['name'] = img['alt'] ? img['alt'] : img['title']
        @images << image 
      end
    end
  end


  # Gets the path to various files referred in the current html
  def files
    file_types = %w(.pdf .doc .docx .xls .xlsx .ppt .pptx .swf .fla .zip)
    @doc.css('a').each do |a|
      href = a['href']
        unless href.blank? 
        if file_types.include? File.extname(href)
              #unless href.include? "http"
                file = Hash.new
                file['href'] = href
                file['name'] = a.text
                @files << file 
              #end
            end
        end
    end
  end

  def process_links
    # parse for internal links and replace them with new links
    file_types = %w(.htm .html)
    @body.css('a').each do |a|
      href = a['href']
        unless href.blank? 
        if file_types.include? File.extname(href)
              uri = URI(URI.encode(href))
              if(uri.host.nil? || uri.host == 'auroville.org' || uri.host == 'www.auroville.org')
                content_path = URI.decode(File.expand_path File.dirname(@path) + '/' + href)
                legacy_path = content_path.sub(@base_path, '')
                c = Content.where(:legacy_path => legacy_path).first
                puts c.class
                if c.blank? 
                  c = Content.create(
                       :legacy_path => legacy_path,
                       :migration_status => 'Placeholder'
                       )
                  c.save!
                end
                a['href'] = '/contents/' + c.id.to_s
              end
            end
        end
    end
  end


  # Gets the body of the content by removing unwanted html code for 
  # menu, header, breadcrumbs from static site content
  def body
    @body = @doc.clone
    @body.css(".path").remove
    @body.css("table[bgcolor='#003399']").remove

    # remove the dynamic html menu from the imported content
    @body.css("#HM_Menu1").remove
    @body.css("#HM_Menu2").remove
    @body.css("#HM_Menu3").remove
    @body.css("#HM_Menu4").remove
    @body.css("#HM_Menu5").remove
    @body.css("#HM_Menu6").remove

    @body.css('p').each do |ele|
      ele.remove if ele.content.strip.empty? 
    end
    
    # convert <b> to <strong>
    @body.css('b').each do |el|
      el.name = 'strong'
    end

    process_links()

    @body = @body.css("body").inner_html

    # remove unwanted space
    @body = @body.gsub(/&nbsp;/, ' ')
    @body = @body.gsub(/\s+/, ' ')

    # encode the content as unicode
    @body.encode! 'utf-8' 

    # @body.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    # puts @body
    # @body = @body.gsub('&nbsp;', ' ')
    # @body = @body.gsub(/\s+/, ' ')


    # # remove empty tags
    # emptynode_clean = lambda {|env|
    #   node = env[:node]
    #   return unless node.elem?
    #   unless node.children.any?{|c| c.text? && c.content.strip.length > 0 || !c.text? }
    #     node.unlink
    #   end
    # }

    @body = Sanitize.clean(@body,
             :elements => %w[a abbr b blockquote br cite code dd dfn dl dt em i kbd li mark ol p pre q s ul h1 h2 h3 h4 h5 h6 strong],
             :attributes => {'a' => ['href', 'title']},
             # :transformers => [emptynode_clean]
            )
    
  end


  # Create or find existing images for the current page
  def ref_images
    @images.each do |image| 
      image_path = image['href']
      image_path = URI.decode(File.expand_path File.dirname(@path) + '/' + image_path)
      image_path.force_encoding('binary')
      legacy_path = image_path.sub(@base_path, '')
      i = ImageAsset.where(:legacy_path => legacy_path).first
      if i.blank? and File.exists?(image_path)
        name = image['name'].truncate(255) if !image['name'].nil?
        time = File.mtime(image_path)
        i = ImageAsset.create(
              :image => File.open(image_path, 'rb') , 
              :legacy_path => legacy_path,
              :name => name,
              :created_at => time,
              :updated_at => time
              )
        i.save
      end
      @image_refs << i if !i.blank?
    end
    @image_refs
  end


  # Create or find existing files for the current page
  def ref_files
    @files.each do |file| 
      file_path = file['href']
      file_path = URI.decode(File.expand_path File.dirname(@path) + '/' + file_path)
      file_path.force_encoding('binary')
      legacy_path = file_path.sub(@base_path, '')
      f = FileAsset.where(:legacy_path => legacy_path).first
      if f.blank? and File.exists?(file_path)
        name = file['name'].truncate(255) if !file['name'].nil?
        time = File.mtime(file_path)
        f = FileAsset.create(
             :file => File.open(file_path, 'rb') , 
             :legacy_path => legacy_path,
             :name => name,
             :created_at => time,
             :updated_at => time
             )
        f.save
      end
      @file_refs << f if !f.blank?
    end
    @file_refs
  end

end