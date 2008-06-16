# desc "Explaining what the task does"
# task :latex_renderer do
#   # Task goes here
# end
namespace :latex do
  desc "Creates required directories"
  task :mkdirs do
    FileUtils.mkdir_p(File.join(RAILS_ROOT, 'log'))
    puts "log/ OK"
    FileUtils.mkdir_p(File.join(RAILS_ROOT, 'tmp'))
    puts "tmp/ OK"
    FileUtils.mkdir_p(File.join(RAILS_ROOT, 'public/images/latex'))
    puts "public/images/latex/ OK"
  end
end
