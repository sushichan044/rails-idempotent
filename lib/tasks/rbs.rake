# frozen_string_literal: true

return unless Rails.env.development?

require 'rbs_rails/rake_task'

RbsRails::RakeTask.new

namespace :rbs do
  task typegen: %i[clean collection rbs_inline eager_load_routes rbs_rails:all]

  desc 'Remove all RBS files'
  task clean: :environment do
    desc 'Remove all RBS files'
    sh 'rm -rf sig/generated/'
    sh 'rm -rf sig/rbs_rails/'
    sh 'rm -rf .gem_rbs_collection'
  end

  desc 'Install RBS files for Rails'
  task collection: :environment do
    sh 'rbs collection install --frozen'
  end

  desc 'Run rbs-inline to generate RBS files'
  task rbs_inline: :environment do
    sh 'rbs-inline --output app lib'
  end

  desc 'Eager load Rails routes, see: https://www.timedia.co.jp/tech/20241114-tech/'
  task eager_load_routes: :environment do
    Rails.application.reload_routes_unless_loaded
  end

  desc 'Validate RBS files'
  task validate: :environment do
    sh 'rbs -Isig validate'
  end
end
