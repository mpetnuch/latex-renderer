require 'digest/md5'
require 'open4'
require 'fileutils'
class LatexRenderer

  attr_accessor :filepath

  def initialize(formula, options = {})

    @options = {
      :image_dir         => File.join(RAILS_ROOT, '/public/images/latex/'),
      :temp_dir          => File.join(RAILS_ROOT, '/tmp/'),
      :density           => 200,
      :text_color        => 'black',
      :background_color  => 'white',
      :latex_class       => 'article',
      :image_format      => 'png',
    }

    #@options.assert_valid_keys = @options.keys
    @options.update(options)
    @options[:blacklist_commands] = %w{
      include def command loop repeat open toks output input
      catcode name \\every \\errhelp \\errorstopmode \\scrollmode
      \\nonstopmode \\batchmode \\read \\write csname \\newhelp
      \\uppercase \\lowercase \\relax \\aftergroup \\afterassignment
      \\expandafter \\noexpand \\special
    }

    @formula = formula
    raise "Dirty object" unless self.is_clean?

    @tex_file, @dvi_file, @ps_file, @img_file, @filepath = nil

  end

  def template
    [
      "\\documentclass{#{@options[:latex_class]}}",
      '\usepackage[latin1]{inputenc}',
      '\usepackage{amsmath}',
      '\usepackage{amsfonts}',
      '\usepackage{amssymb}',
      '\pagestyle{empty}',
      '\begin{document}',
      '\begin{center}',
      @formula,
      '\end{center}',
      '\end{document}',
    ].join("\n")
  end

  def render
    md5hash = Digest::MD5.hexdigest(@formula).to_s
    filename = md5hash + '.' + @options[:image_format]
    @filepath = File.join(@options[:image_dir], filename)
    unless File.exists? @filepath
      begin
        self.create_temp_files(md5hash)
        self.latex_to_dvi
        self.dvi_to_ps
        self.ps_to_image
        FileUtils.copy @img_file, @filepath
      ensure
        self.destroy
      end
    end
  end

  def execute(command)
    pid, stdin, stdout, stderr = Open4::popen4 command
    ignored, status = Process::waitpid2 pid
    err = stderr.readlines.join("\n")
    output = stdout.readlines.join("\n")
    [stdin,stdout,stderr].each{|pipe| pipe.close}

    if status.exitstatus == 1
      message =" failed.\n #{command} caused the following error(s)\nErr: #{err} .Done"
      raise message
    end
    return output
  end

  def create_temp_files(md5hash)
    @tempdir   = @options[:temp_dir]
    @latex_log = File.join(@tempdir, md5hash + '.log')
    @tex_file  = File.join(@tempdir, md5hash + '.tex')
    @dvi_file  = File.join(@tempdir, md5hash + '.dvi')
    @img_file  = File.join(@tempdir, md5hash + '.png')
    @ps_file   = File.join(@tempdir, md5hash + '.ps')
    @aux       = File.join(@tempdir, md5hash + '.aux')
  end

  def latex_to_dvi
    latex = %x[which latex].strip

    # temp Latex file
    File.open(@tex_file,'w') do |file|
      file.write self.template
    end
    command  = [ latex,  '--interaction=nonstopmode', "--output-directory=#{@tempdir}", @tex_file  ]
    self.execute command.join(' ')
  end

  def dvi_to_ps
    dvips = %x[which dvips].strip # dpi to postscript
    command = [ dvips, "-E #{@dvi_file}", "-o #{@ps_file}" ]
    self.execute command.join(' ')
  end

  def ps_to_image
    convert  = %x[which convert].strip #  convert postscript to imagea
    command  = sprintf '%s \( \( \( -density %s %s -trim \) \( +clone -negate \)' +
                        ' -compose CopyOpacity \) -composite \) -channel RGB -fx "%s" %s',
                        convert, @options[:density].to_s, @ps_file,
                        @options[:text_color], @img_file
    self.execute command
  end

  def is_clean?
    errors = Array.new
    @options[:blacklist_commands].each do |cmd|
      errors.push cmd if @formula.include? cmd
    end
    errors.size
  end

  def destroy
    [@tex_file, @dvi_file, @img_file, @ps_file, @latex_log, @aux ].each do |tmp|
      File.delete(tmp) if File.exists?(tmp)
    end
  end
end
