# frozen_string_literal: true

# rbs_inline: enabled
class UuidValidator < ActiveModel::EachValidator
  # @rbs (untyped, untyped, untyped) -> void
  def validate_each(record, attribute, value) # rubocop:disable Metrics/ AbcSize
    return if value.nil?

    begin
      uuid = UUIDTools::UUID.parse(value)
    rescue ArgumentError, TypeError
      record.errors.add(attribute, options[:message] || 'is not a valid UUID')
      return
    end

    return unless options[:version] && !uuid_version?(uuid, options[:version])

    record.errors.add(attribute, options[:message] || "is not a valid UUID version #{options[:version]}")
  end

  private

  # @rbs (UUIDTools::UUID, Integer) -> bool
  def uuid_version?(uuid, version)
    uuid.version == version
  end
end
