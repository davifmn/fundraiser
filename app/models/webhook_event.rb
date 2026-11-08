class WebhookEvent < ApplicationRecord
  validates :provider, :event_id, :event_type, presence: true

  # Inserts the event unless it is already there. Returns the new record, or nil for an
  # event seen before. The unique index decides, so two concurrent deliveries of the same
  # event cannot both get a record.
  def self.record(provider:, event_id:, event_type:, payload:)
    rows = insert_all(
      [ { provider: provider, event_id: event_id, event_type: event_type, payload: payload } ],
      unique_by: %i[provider event_id],
      returning: %i[id]
    )
    rows.empty? ? nil : find(rows.first["id"])
  end
end
