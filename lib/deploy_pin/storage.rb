# frozen_string_literal: true

module DeployPin
  # Resolves the model used to persist task records, based on the configured storage provider.
  #
  #   DeployPin.setup do
  #     storage :active_record # default, or :mongoid
  #   end
  #
  # A record class must respond to:
  #   .find_by(uuid:)  - returns a record or nil
  #   .create(uuid:)
  # and its instances to:
  #   #progress, #completed_at, #update(attributes), #increment!(attribute, by)
  module Storage
    PROVIDERS = {
      active_record: -> { DeployPin::Record },
      mongoid: -> { DeployPin::MongoidRecord }
    }.freeze

    def self.record_class
      PROVIDERS.fetch(DeployPin.storage.to_sym) do
        raise ArgumentError,
              "Unknown DeployPin storage #{DeployPin.storage.inspect}. Supported: #{PROVIDERS.keys.join(', ')}"
      end.call
    end
  end
end
