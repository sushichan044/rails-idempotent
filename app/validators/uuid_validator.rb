# frozen_string_literal: true

# rbs_inline: enabled
class UuidValidator < ActiveModel::EachValidator
  # @rbs (untyped, untyped, untyped) -> void
  def validate_each(record, attribute, value) # rubocop:disable Metrics/ AbcSize
    return if value.nil?

    record.errors.add(attribute, options[:message] || 'is not a valid UUID') unless uuid?(value)

    return unless options[:version] && !uuid_version?(value, options[:version])

    record.errors.add(attribute, options[:message] || "is not a valid UUID version #{options[:version]}")
  end

  private

  # @rbs (String) -> bool
  def uuid?(string)
    string.match?(UUIDTools::UUID_REGEXP)
  end

  # @rbs (String, Integer) -> bool
  def uuid_version?(string, version)
    begin
      parsed = UUIDTools::UUID.parse(string)
    rescue TypeError, ArgumentError
      return false
    end
    parsed.version == version
  end
end
