
require 'tk'

class UserProfileView < TkFrame
    TITLE_FONT   = 'Helvetica 16 bold'.freeze
    SECTION_FONT = 'Helvetica 12 bold'.freeze
    LABEL_FONT   = 'Helvetica 10 bold'.freeze

    #[section title, [[key, label, entry width], ...]]
    #keys match AppContext#update_profile keywords.
    SECTIONS = [
        ['Account Information', [
                                 [:username, 'Username:', 30],
                                 [:email,    'Email:',    30]
                                ]],
        ['Address Details', [
                             [:street, 'Street Address:', 30],
                             [:city,   'City:',           30],
                             [:state,  'State:',          10],
                             [:zip,    'Zip Code:',       15]
                            ]]
    ].freeze

    def initialize(parent, app)
        super(parent)
        @app     = app
        @entries = {}
        build_header
        build_form
        populate_fields
    end

    private

    #layout

    def build_header
        header = TkFrame.new(self).pack(fill: 'x', pady: 10)
        TkLabel.new(header, text: 'User Profile & Address', font: TITLE_FONT).pack(side: 'left', padx: 10)
        TkButton.new(header, text: 'Back to Dashboard', command: proc { go_back }).pack(side: 'right', padx: 10)
    end

    def build_form
        form = TkFrame.new(self).pack(padx: 20, pady: 10)
        row = 0

        SECTIONS.each_with_index do |(title, fields), i|
            top_gap = i.zero? ? 0 : 15
            TkLabel.new(form, text: title, font: SECTION_FONT)
            .grid(row: row, column: 0, columnspan: 2, sticky: 'w', pady: [top_gap, 10])
            row += 1

            fields.each do |key, label, width|
                TkLabel.new(form, text: label, font: LABEL_FONT).grid(row: row, column: 0, sticky: 'e', padx: 5, pady: 5)
                entry = TkEntry.new(form, width: width)
                entry.grid(row: row, column: 1, sticky: 'w', padx: 5, pady: 5)
                @entries[key] = entry
                row += 1
            end
        end

        TkButton.new(form, text: 'Save Profile', command: proc { save_profile })
        .grid(row: row, column: 1, sticky: 'w', pady: 15)
    end

    #auto fills form with user details
    def populate_fields
        user = @app.current_user
        return unless user

        values = { username: user[:username], email: user[:email] }.merge(user[:address] || {})
        @entries.each { |key, entry| entry.value = values[key].to_s }
    end

    #actions

    def save_profile
        values = @entries.transform_values { |entry| entry.value.strip }
        ok, msg = @app.update_profile(**values)

        Tk.messageBox(type: 'ok', icon: ok ? 'info' : 'error',
                      title: ok ? 'Success' : 'Validation Error', message: msg)
    end

    def go_back
        @app.switch_to(@app.admin? ? AdminDashboardView : UserDashboardView)
    end
end
