require "test_helper"

class WebhookEventTest < ActiveSupport::TestCase
  test "an event is recorded once; a repeat returns nil" do
    first = WebhookEvent.record(provider: "stripe", event_id: "evt_1", event_type: "x", payload: { "a" => 1 })
    again = WebhookEvent.record(provider: "stripe", event_id: "evt_1", event_type: "x", payload: { "a" => 1 })

    assert_instance_of WebhookEvent, first
    assert_nil again
    assert_equal 1, WebhookEvent.where(event_id: "evt_1").count
  end
end
