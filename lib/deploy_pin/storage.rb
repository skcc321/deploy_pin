# frozen_string_literal: true

module DeployPin
  # Resolves the model used to persist task records, based on the configured storage provider.
  #
  # @example
  #   DeployPin.setup do
  #     storage :active_record # default, or :mongoid
  #   end
  #
  # A record class must respond to `.find_by(uuid:)` (returning a record or
  # nil) and `.create(uuid:)`. Its instances must respond to `#progress`,
  # `#completed_at`, `#update(attributes)` and `#increment!(attribute, by)`.
  module Storage
    # Record classes by storage name. They are resolved lazily, so only the
    # configured ORM has to be installed.
    PROVIDERS = {
      active_record: -> { DeployPin::Record },
      mongoid: -> { DeployPin::MongoidRecord }
    }.freeze

    # @return [Class] {Record} or {MongoidRecord}
    # @raise [ArgumentError] if {DeployPin.storage} is not one of {PROVIDERS}
    def self.record_class
      PROVIDERS.fetch(DeployPin.storage.to_sym) do
        raise ArgumentError,
              "Unknown DeployPin storage #{DeployPin.storage.inspect}. Supported: #{PROVIDERS.keys.join(', ')}"
      end.call
    end
  end
end
