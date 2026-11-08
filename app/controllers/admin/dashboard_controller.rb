module Admin
  class DashboardController < ApplicationController
    http_basic_authenticate_with(
      name: ENV.fetch("ADMIN_USER", "admin"),
      password: ENV.fetch("ADMIN_PASSWORD") { Rails.env.production? ? raise("ADMIN_PASSWORD is not set") : "secret" }
    )

    def index
      @report = Reports::Dashboard.new
    end
  end
end
