# frozen_string_literal: true

module DeployPin
  # Mongoid storage for task records, enabled with `storage :mongoid`.
  # :reek:MissingSafeMethod - increment! mirrors the ActiveRecord API used by DeployPin::Task.
  class MongoidRecord
    include ::Mongoid::Document
    include ::Mongoid::Timestamps

    store_in collection: 'deploy_pins'

    field :uuid, type: String
    field :progress, type: Integer, default: 0
    field :completed_at, type: Time

    index({ uuid: 1 }, { unique: true })

    # Same semantics as ActiveRecord: nil when missing (Mongoid raises by default).
    def self.find_by(uuid:)
      where(uuid: uuid&.to_s).first
    end

    # Atomic, like ActiveRecord's increment!.
    def increment!(attribute, by = 1)
      inc(attribute => by)
    end
  end
end
