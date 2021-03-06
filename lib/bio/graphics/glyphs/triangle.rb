# 
# = bio/graphics/glyphs/triangle - triangle glyph
#
# Copyright::   Copyright (C) 2007, 2008
#               Jan Aerts <jan.aerts@bbsrc.ac.uk>
#               Charles Comstock <dgtized@gmail.com>
# License::     The Ruby License
#

module Bio::Graphics::Glyph
  class Bio::Graphics::Glyph::Triangle < Bio::Graphics::Glyph::Common
    def left_pixel
      return @subfeature.pixel_range_collection[0].lend - Bio::Graphics::FEATURE_ARROW_LENGTH
    end

    def right_pixel
      return @subfeature.pixel_range_collection[0].rend + Bio::Graphics::FEATURE_ARROW_LENGTH
    end
    
    def draw
      raise "Start and stop are not the same (necessary if you want triangle glyphs)" if @subfeature.start != @subfeature.stop
      
      arrow(@feature_context,:north, self.left_pixel + Bio::Graphics::FEATURE_ARROW_LENGTH, 0, Bio::Graphics::FEATURE_ARROW_LENGTH)
      @feature_context.close_path.stroke
    end
  end
end
