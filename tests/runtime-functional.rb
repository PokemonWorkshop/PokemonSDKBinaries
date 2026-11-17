require 'rbconfig'
require 'tmpdir'
RUNTIME_ROOT = File.expand_path('../..', __dir__)
# Exercise decoding without depending on the runner's physical audio device.
ENV['ALSOFT_DRIVERS'] = 'null'
abort 'Expected Ruby 3.4.10' unless RUBY_VERSION == '3.4.10'
platform = ENV.fetch('PSDK_TEST_PLATFORM')
expected_platform, pointer_bytes, codec_path, utility_path = {
  'windows' => [/\Ai386-mingw32\z/, 4, 'ruby_builtin_dlls/avcodec-60.dll', 'ruby_builtin_dlls/avutil-58.dll'],
  'macos' => [/\Aarm64-darwin/, 8, 'lib/libavcodec.60.dylib', 'lib/libavutil.58.dylib'],
  'linux' => [/\Ax86_64-linux/, 8, 'lib/libavcodec.so.60', 'lib/libavutil.so.58']
}.fetch(platform)
abort "Unexpected platform: #{RUBY_PLATFORM}" unless expected_platform.match?(RUBY_PLATFORM)
abort 'Unexpected pointer size' unless [0].pack('J').bytesize == pointer_bytes
AVCODEC_PATH = File.join(RUNTIME_ROOT, codec_path)
AVUTIL_PATH = File.join(RUNTIME_ROOT, utility_path)
$stdout.sync = true
abort 'RubyGems unexpectedly enabled' if ENV['PSDK_EXPECT_NO_GEMS'] == '1' && defined?(Gem)
%w[openssl psych zlib fiddle/import socket json bigdecimal date stringio strscan
   uri net/http yaml csv rexml/document rss matrix prime net/ftp net/imap
   net/pop net/smtp mutex_m getoptlong base64 observer abbrev resolv-replace
   rinda/rinda drb/drb nkf racc/parser
   LiteRGSS SFMLAudio RubyFmod SFEMovie].each do |name|
  puts "Loading #{name}"
  require name
end
require 'clean_load_path' unless platform == 'windows'
abort 'YAML failed' unless Psych.safe_load('test: 42')['test'] == 42
abort 'CSV failed' unless CSV.parse("name,value\nPSDK,42\n", headers: true)[0]['value'] == '42'
abort 'REXML failed' unless REXML::Document.new('<psdk>42</psdk>').root.text == '42'
abort 'NKF failed' unless NKF.nkf('-w', 'PSDK') == 'PSDK'
abort 'RubyGems loaded during legacy requires' if ENV['PSDK_EXPECT_NO_GEMS'] == '1' && defined?(Gem)
abort 'zlib failed' unless Zlib.inflate(Zlib.deflate('PSDK')) == 'PSDK'
abort 'OpenSSL failed' unless OpenSSL::Digest::SHA256.hexdigest('PSDK').size == 64
abort "Unexpected OpenSSL headers: #{OpenSSL::OPENSSL_VERSION}" unless OpenSSL::OPENSSL_VERSION.split[1] == '3.5.9'
abort "Unexpected OpenSSL runtime: #{OpenSSL::OPENSSL_LIBRARY_VERSION}" unless OpenSSL::OPENSSL_LIBRARY_VERSION.split[1] == '3.5.9'
abort 'Missing graphics API' unless defined?(LiteRGSS::Bitmap)
abort 'Expected LiteCGSS fixed shader pipeline' unless LiteRGSS::Shader::LITECGSS_SHADER_FIXED_PIPELINE == true
abort 'Missing audio API' unless defined?(SFMLAudio::Music)
abort 'Unexpected FMOD API version' unless FMOD::VERSION == 0x00020220
abort 'Missing movie API' unless defined?(SFE::Movie)
FMOD::System.setOutput(FMOD::OUTPUTTYPE::NOSOUND)
FMOD::System.init(8, FMOD::INIT::NORMAL)
abort 'FMOD runtime version mismatch' unless FMOD::System.getVersion == 0x00020220
Dir.mktmpdir('psdk-audio-') do |directory|
  samples = "\0".b * 8820
  wave = 'RIFF'.b + [36 + samples.bytesize].pack('V') + 'WAVEfmt '.b +
         [16, 1, 1, 44_100, 88_200, 2, 16].pack('VvvVVvv') + 'data'.b +
         [samples.bytesize].pack('V') + samples
  filename = File.join(directory, 'smoke.wav')
  File.binwrite(filename, wave)
  begin
    sound = FMOD::System.createSound(filename, FMOD::MODE::FMOD_2D, nil)
    abort 'FMOD PCM decode failed' unless sound.getLength(FMOD::TIMEUNIT::MS) == 100
    music = SFMLAudio::Music.new
    abort 'SFML PCM decode failed' unless music.open_from_file(filename)
    abort 'SFML duration failed' unless (music.get_duration - 0.1).abs < 0.001
    puts 'Testing sfeMovie PCM audio and resampler initialization'
    movie = SFE::Movie.new
    abort 'sfeMovie PCM audio open failed' unless movie.open_from_file(filename)
    abort 'sfeMovie audio duration mismatch' unless (movie.get_duration - 0.1).abs < 0.001
    movie.play
    5.times { sleep 0.03; movie.update }
    movie.stop unless movie.stopped?
  ensure
    sound&.release
    music = nil
    movie = nil
    GC.start(full_mark: true, immediate_sweep: true)
  end
end
FMOD::System.close
FMOD::System.release
SFE::Movie.new
module AVCodec
  extend Fiddle::Importer
  dlload AVCODEC_PATH
  extern 'void *avcodec_find_decoder_by_name(const char *)'
end
module AVUtil
  extend Fiddle::Importer
  dlload AVUTIL_PATH
  extern 'const char *av_version_info()'
end
abort "Unexpected FFmpeg runtime: #{AVUtil.av_version_info}" unless AVUtil.av_version_info.to_s == '6.1.6'
%w[png mov_text h264 vorbis aac].each do |decoder|
  abort "Missing decoder: #{decoder}" if AVCodec.avcodec_find_decoder_by_name(decoder).to_i.zero?
end
load File.join(__dir__, 'sfemovie-texture.rb')
normalize = ->(path) do
  expanded = File.expand_path(path).tr('\\', '/')
  platform == 'windows' ? expanded.downcase : expanded
end
root = normalize.call(RUNTIME_ROOT) + '/'
foreign = $LOADED_FEATURES.select { |p| p =~ /\A(?:[A-Za-z]:|\/)/ && !normalize.call(p).start_with?(root) }
abort "Loaded foreign Ruby files: #{foreign}" unless foreign.empty?
puts "Shared functional suite passed: #{platform}"
File.write(ENV['PSDK_SMOKE_RESULT'], "passed\n") if ENV['PSDK_SMOKE_RESULT']
