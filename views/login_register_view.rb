require 'tk'

class LoginRegisterView < TkFrame
    TITLE_FONT   = 'Helvetica 16 bold'.freeze
    SECTION_FONT = 'Helvetica 10 bold'.freeze

    # [key, label, secret?]
    USER_FIELDS = [
        [:username, 'Username (>=3 chars):'],
        [:email,    'Email:'],
        [:password, 'Password (>=6 chars):', true]
    ].freeze

    ADDRESS_FIELDS = [
        [:street, 'Street:'],
        [:city,   'City:'],
        [:state,  'State:'],
        [:zip,    'Zip Code:']
    ].freeze

    # sets up the view and shows the login screen
    def initialize(parent, app)
        super(parent)
        @app = app
        build_login_ui
    end

    # builds the login screen
    def build_login_ui(notice = nil)
        clear_frame
        title('UserHub System Login')

        @username_entry = labeled_entry('Username / Email:')
        @password_entry = labeled_entry('Password:', secret: true)
        @error_label    = error_label
        TkLabel.new(self, text: notice, foreground: 'dark green').pack(pady: 5) if notice

        button('Login')              { handle_login }
        button('Go to Registration') { build_register_ui }

        @password_entry.bind('Return') { handle_login }
        @username_entry.focus
    end

    # builds the registration form
    def build_register_ui
        clear_frame
        title('User & Address Registration')

        @reg = {}
        USER_FIELDS.each { |key, label, secret| @reg[key] = labeled_entry(label, secret: secret, pady: 0) }
        TkLabel.new(self, text: '--- Address Information ---', font: SECTION_FONT).pack(pady: 5)
        ADDRESS_FIELDS.each { |key, label| @reg[key] = labeled_entry(label, pady: 0) }
        @reg_error = error_label

        button('Submit Registration') { handle_registration }
        button('Back to Login')       { build_login_ui }

        @reg[:username].focus
    end

    private

    # widget helpers

    # adds a title label
    def title(text)
        TkLabel.new(self, text: text, font: TITLE_FONT).pack(pady: 10)
    end

    # adds a label and text entry
    def labeled_entry(label, secret: false, pady: 5)
        TkLabel.new(self, text: label).pack
        options = secret ? { show: '*' } : {}
        TkEntry.new(self, options).pack(pady: pady)
    end

    # adds a red error label
    def error_label
        TkLabel.new(self, foreground: 'red').pack(pady: 5)
    end

    # adds a button that runs the given block
    def button(text, &action)
        TkButton.new(self, text: text, command: action).pack(pady: 5)
    end

    # removes all widgets from the screen
    def clear_frame
        TkWinfo.children(self).each(&:destroy)
    end

    # handlers

    # logs in and opens the right dashboard
    def handle_login
        if @app.authenticate(@username_entry.value.strip, @password_entry.value)
            @app.switch_to(@app.admin? ? AdminDashboardView : UserDashboardView)
        else
            @password_entry.value = ''
            @error_label.text = 'Invalid credentials.'
        end
    end

    # submits the registration form
    def handle_registration
        values = @reg.to_h { |key, entry| [key, key == :password ? entry.value : entry.value.strip] }

        ok, msg = @app.register_user(**values)
        if ok
            build_login_ui(msg)
        else
            @reg_error.text = msg
        end
    end
end
