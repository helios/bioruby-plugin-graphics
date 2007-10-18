# 
# = bio/graphics/panel - panel class
#
# Copyright::   Copyright (C) 2007
#               Jan Aerts <jan.aerts@bbsrc.ac.uk>
# License::     The Ruby License
#
module Bio
  # = DESCRIPTION
  # The Bio::Graphics set of objects allow for creating simple images that
  # display features on a linear map. A picture consists of:
  # * one *panel*: container of all tracks
  # * one or more *tracks*: container of the features. Multiple tracks
  #   can exist in the same graphic to allow for differential visualization of
  #   different feature types (e.g. genes as blue rectangles and polymorphisms
  #   as red triangles)
  # * one or more *features* in each track: these are the actual features that
  #   you want to display (e.g. 'gene 1', 'SNP 123445')
  # * a *ruler* on top of the panel: is added automatically
  #
  # Schematically:
  #  panel
  #    +-> track 1
  #    |     +-> feature 1
  #    |     +-> feature 2
  #    |     +-> feature 3
  #    +-> track 2
  #    |     +-> feature 4
  #    |     +-> feature 5
  #    +-> ruler
  #
  # = USAGE
  #   # Create a panel for something with a length of 653. This could be a
  #   # sequence of 653 bp, but also a genetic map of 653 cM.
  #   g = Bio::Graphics::Panel.new(653)
  #
  #   # Add the first track (e.g. 'genes')
  #   track1 = g.add_track('genes')
  #
  #   # And put features in that track
  #   track1.add_feature('gene1',250,375)
  #   track1.add_feature('gene2',54,124)
  #   track1.add_feature('gene3',100,500)
  #
  #   # Add a second track (e.g. 'polymorphisms')
  #   track2 = g.add_track('polymorphisms',, false, 'red','triangle')
  #
  #   # And put features on this one
  #   track2.add_feature('polymorphism 1',56,56)
  #   track2.add_feature('polymorphism 2',103,103)
  #
  #   # Create the actual image as SVG text
  #   g.draw('my_picture.png')
  #
  # = FUTURE PROSPECTS
  # Any help from other developers is welcomed to work on these features:
  # * Would be nice if this module would be easily accessible from any object
  #   that implements bioruby's Bio::Map::ActsAsMap.
  #
  module Graphics

    # The defaults
    DEFAULT_PANEL_WIDTH = 800  # How many pixels wide do we want the picture to be?
    TRACK_HEADER_HEIGHT = 12   # The track header will contain the title.
    FEATURE_HEIGHT = 10        # The height in pixels of a glyph.
    FEATURE_V_DISTANCE = 5     # The vertical distance in pixels between glyphs
    FEATURE_ARROW_LENGTH = 5   # In pixels again.
    RULER_TEXT_HEIGHT = 10     # And again...
    RULER_MIN_DISTANCE_TICKS_PIXEL = 5  # There should be at least 5 pixels between
                                        #   consecutive ticks. This is used for the
                                        #   calculation of tick distance.
    FONT = ['Georgia', 1, 1]

    # The Bio::Graphics::Panel class describes the complete graph and contains
    # all tracks. See Bio::Graphics documentation for explanation of interplay
    # between different classes.
    
    class Panel
      # Create a new Bio::Graphics::Panel object
      #
      #   g = Bio::Graphics::Panel.new(456)
      #
      # The height of the image is calculated automatically depending on how many
      # tracks and features it contains. The width of the image defaults to 800 pt
      # but can be set manually by using a second argument:
      #
      #   g = Bio::Graphics::Panel.new(456, 400)
      #
      #
      # See also: Bio::Graphics::Track, BioExt::Graphics::Feature
      # ---
      # *Arguments*:
      # * _length_ :: length of the thing you want to visualize, e.g for
      #   visualizing a sequence that is 3.24 kb long, use 324.
      # * _width_ :: width of the resulting image in pt. This should be a string
      #   and not an integer. Default = '800' (Notice the quotes...).
      # * _clickable_ :: whether the picture should have clickable glyphs or not
      #   (default: false) If set to true, a html file will be created with
      #   the map.
      # * _display_start_ :: start coordinate to be displayed (default: 1)
      # * _display_stop_ :: stop coordinate to be displayed (default: length of sequence)
      # *Returns*:: Bio::Graphics::Panel object
      def initialize(length, width = DEFAULT_PANEL_WIDTH, clickable = false, display_start = nil, display_stop = nil)
        @length = length.to_i
        @width = width.to_i
        @tracks = Array.new
        @number_of_feature_rows = 0
        @clickable = clickable
        @image_map = ( clickable ) ? ImageMap.new : nil
        @display_start = ( display_start.nil? or display_start < 0 ) ? 0 : display_start
        @display_stop = ( display_stop.nil? or display_stop > @length ) ? @length : display_stop
        if @display_stop <= @display_start
          raise "[ERROR] Start coordinate to be displayed has to be smaller than stop coordinate."
        end
        @rescale_factor = (@display_stop - @display_start).to_f / @width
      end
      attr_accessor :length, :width, :height, :rescale_factor, :tracks, :number_of_feature_rows, :clickable, :image_map, :display_start, :display_stop

      # Adds a Bio::Graphics::Track container to this panel. A panel contains a
      # logical grouping of features, e.g. (for sequence annotation:) genes,
      # polymorphisms, ESTs, etc.
      #
      #  est_track = g.add_track('ESTs')
      #  gene_track = g.add_track('genes')
      #
      # ---
      # *Arguments*:
      # * _name_ (required) :: Name of the track to be displayed (e.g. 'genes')
      # * _label) :: Whether the feature labels should be displayed or not
      # * _colour_ :: Colour to be used to draw the features within the track.
      #   Default = 'blue'
      # * _glyph_ :: Glyph to use for drawing the features. Options are:
      #   'generic', 'directed_generic', 'spliced', 'directed_spliced' and
      #   'triangle'. Triangles can be used
      #   for features whose start and stop positions are the same (e.g. SNPs).
      #   If you try to draw a feature that is longer with triangles, an error
      #   will be shown.
      # *Returns*:: Bio::Graphics::Track object that has just been created
      def add_track(name, label = true, feature_colour = [0,0,1], feature_glyph = 'generic')
        @tracks.push(Bio::Graphics::Panel::Track.new(self, name, label, feature_colour, feature_glyph))
        return @tracks[-1]
      end

      # Create the drawing
      #--
      # The fact that display_start and display_stop can be set has two
      # consequences:
      #  1. not all features are drawn
      #  2. the x-coordinate of all glyphs has to be corrected
      #++
      def draw(file_name)
        # Create a panel that is huge vertically
        huge_height = 2000

        huge_panel_drawing = nil
        huge_panel_drawing = Cairo::ImageSurface.new(1, @width, huge_height)

        background = Cairo::Context.new(huge_panel_drawing)
        background.set_source_rgb(1,1,1)
        background.rectangle(0,0,@width,huge_height).fill

        # Add ruler
        vertical_offset = 0
        ruler = Bio::Graphics::Panel::Ruler.new(self)
        ruler.draw(huge_panel_drawing, vertical_offset)
        vertical_offset += ruler.height

        # Add tracks
        @tracks.each do |track|
          track.vertical_offset = vertical_offset
          track.draw(huge_panel_drawing)
          @number_of_feature_rows += track.number_of_feature_rows
          vertical_offset += ( track.number_of_feature_rows*(FEATURE_HEIGHT+FEATURE_V_DISTANCE+5)) + 10 # '10' is for the header
        end

        # And create a smaller version of the panel
        height = ruler.height
        @number_of_feature_rows.times do
          height += 20
        end
        @tracks.length.times do #To correct for the track headers
          height += 10
        end

        resized_panel_drawing = nil
        resized_panel_drawing = Cairo::ImageSurface.new(1, @width, height)
        resizing_context = Cairo::Context.new(resized_panel_drawing)
        resizing_context.set_source(huge_panel_drawing, 0,0)
        resizing_context.rectangle(0,0,@width, height).fill

        # And print to file
        resized_panel_drawing.write_to_png(file_name)
        if @clickable # create png and map
          html_filename = file_name.sub(/\.[^.]+$/, '.html')
          html = File.open(html_filename,'w')
          html.puts "<html>"
          html.puts "<body>"
          html.puts @image_map.to_s
          html.puts "<img border='1' src='" + file_name + "' usemap='#image_map' />"
          html.puts "</body>"
          html.puts "</html>"
        end
      end



    end #Panel
  end #Graphics
end #Bio
