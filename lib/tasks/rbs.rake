# frozen_string_literal: true

return unless Rails.env.development?

require 'rbs_rails/rake_task'

RbsRails::RakeTask.new

namespace :rbs do
  task setup: %i[clean collection rbs_inline rbs_rails:all]

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

  desc 'Validate RBS files'
  task validate: :environment do
    sh 'rbs -Isig validate'
  end
end
