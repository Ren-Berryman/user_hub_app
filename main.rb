require_relative 'app_context'
require_relative 'helpers/validator'
require_relative 'views/login_register_view'
require_relative 'views/user_dashboard_view'
require_relative 'views/admin_dashboard_view'

app = AppContext.new
app.switch_to(LoginRegisterView)
app.run
