# A self-contained video regression: no encoder, download or audio device.
require 'zlib'
require 'tmpdir'
require 'LiteRGSS'
require 'SFEMovie'

def riff_chunk(id, data)
  id.b + [data.bytesize].pack('V') + data + (data.bytesize.odd? ? "\0" : '')
end

def png_chunk(id, data)
  [data.bytesize].pack('N') + id + data + [Zlib.crc32(id + data)].pack('N')
end

Dir.mktmpdir('sfemovie-texture-') do |directory|
  begin
  width = height = 16
  frames = 25
  pixels = [0, 255, 0].pack('C*') * width * height # BGR, aligned rows
  avih = [40_000, pixels.bytesize * frames, 0, 0, frames, 0, 1,
          pixels.bytesize, width, height, 0, 0, 0, 0].pack('V*')
  strh = 'vidsDIB '.b + [0, 0, 0, 0, 1, frames, 0, frames,
                       pixels.bytesize, 0xffffffff, 0, 0, 0, width, height].pack('VvvV8v4')
  strf = [40, width, height, 1, 24, 0, pixels.bytesize, 0, 0, 0, 0].pack('V3v2V6')
  headers = riff_chunk('LIST', 'hdrl' + riff_chunk('avih', avih) +
                      riff_chunk('LIST', 'strl' + riff_chunk('strh', strh) + riff_chunk('strf', strf)))
  video = riff_chunk('RIFF', 'AVI ' + headers +
                    riff_chunk('LIST', 'movi' + riff_chunk('00db', pixels) * frames))
  filename = File.join(directory, 'green.avi')
  File.binwrite(filename, video)
  png = "\x89PNG\r\n\x1a\n".b + png_chunk('IHDR', [width, height, 8, 6, 0, 0, 0].pack('N2C5')) +
        png_chunk('IDAT', Zlib.deflate(("\0".b + [0, 255, 0, 255].pack('C*') * width) * height)) +
        png_chunk('IEND', ''.b)
  reference = LiteRGSS::Bitmap.new(png, true)
  expected = reference.to_png
  movie = SFE::Movie.new
  raise 'Cannot open generated video' unless movie.open_from_file(filename)
  raise 'Wrong video dimensions' unless movie.get_size == [width, height]
  movie.play
  movie.update
  # The native player publishes its first frame when its clock reaches the
  # next packet timestamp; play/update can both run inside that first tick.
  sleep 0.06
  movie.update
  # PSDK's Texture inherits the native Bitmap allocator.
  texture_class = Class.new(LiteRGSS::Bitmap)
  [LiteRGSS::Bitmap, texture_class].each do |klass|
    texture = klass.new(width, height)
    movie.update_bitmap(texture)
    raise 'Video pixels did not reach texture' unless texture.to_png == expected
    texture.dispose
    begin
      movie.update_bitmap(texture)
      raise 'Disposed texture was accepted'
    rescue LiteRGSS::Error
      # Native pointer must be checked before dereferencing.
    end
    uninitialized = klass.allocate
    begin
      movie.update_bitmap(uninitialized)
      raise 'Uninitialized texture was accepted'
    rescue LiteRGSS::Error
    ensure
      uninitialized.dispose
    end
  end
  # Keep the existing no-op behavior for unrelated Ruby objects.
  raise 'Wrong-type behavior changed' unless movie.update_bitmap(Object.new).nil?
  snapshot = movie.get_current_texture
  raise 'Movie snapshot was not initialized' unless snapshot.is_a?(LiteRGSS::Bitmap)
  raise 'Movie snapshot pixels differ' unless snapshot.to_png == expected
  snapshot.dispose
  reference.dispose
  ensure
    # stop only pauses the demuxer; Windows cannot unlink its open AVI file.
    # Release the native Movie before Dir.mktmpdir removes the fixture.
    movie&.stop
    movie = nil
    GC.start(full_mark: true, immediate_sweep: true)
  end
end
puts 'SFEMovie texture transfer, snapshot, subclass and disposal checks passed.'
