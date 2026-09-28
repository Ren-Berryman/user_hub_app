require 'tk'

class UserProfileView < TkFrame
    TITLE_FONT   = 'Helvetica 16 bold'.freeze
    SECTION_FONT = 'Helvetica 12 bold'.freeze
    LABEL_FONT   = 'Helvetica 10 bold'.freeze
    PICTURE_SIZE = 120   # longest side of the displayed picture, in pixels
    NO_PICTURE   = '(no picture)'.freeze

    # [section title, [[key, label, entry width], ...]]
    # Keys match AppContext#update_profile keywords.
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

    # sets up the profile view
    def initialize(parent, app)
        super(parent)
        @app     = app
        @entries = {}
        build_header
        build_picture_area   # creates @picture_label
        build_form
        populate_fields
        show_picture
    end

    private

    # layout

    # builds the title bar and back button
    def build_header
        header = TkFrame.new(self).pack(fill: 'x', pady: 10)
        TkLabel.new(header, text: 'User Profile & Address', font: TITLE_FONT).pack(side: 'left', padx: 10)
        TkButton.new(header, text: 'Back to Dashboard', command: proc { go_back }).pack(side: 'right', padx: 10)
    end

    # builds the profile picture box and its buttons
    def build_picture_area
        TkLabel.new(self, text: 'Profile Picture', font: SECTION_FONT).pack(pady: 5)
 
        @picture_label = TkLabel.new(self, text: NO_PICTURE, relief: 'groove', padx: 10, pady: 10)
        @picture_label.pack(pady: 5)
 
        row = TkFrame.new(self).pack(pady: 5)
        TkButton.new(row, text: 'Choose Picture...', command: proc { choose_picture }).pack(side: 'left', padx: 5)
        TkButton.new(row, text: 'Remove Picture',    command: proc { remove_picture }).pack(side: 'left', padx: 5)
    end

    # builds the account and address form
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

    # fills the form with the current user info
    def populate_fields
        user = @app.current_user
        return unless user

        values = { username: user[:username], email: user[:email] }.merge(user[:address] || {})
        @entries.each { |key, entry| entry.value = values[key].to_s }
    end

    # profile picture
 
    # shows the saved picture, or the placeholder text if there isn't one
    def show_picture
        user = @app.current_user
        path = user && user[:profile_picture]
 
        if path && File.file?(path)
            @photo = load_photo(path)   # keep a reference so Tk doesn't lose the image
            @picture_label.configure(image: @photo, text: '')
        else
            @photo = nil
            @picture_label.configure(image: '', text: NO_PICTURE)
        end
    end
 
    # loads the image and shrinks it (by whole-number factors) to fit PICTURE_SIZE
    def load_photo(path)
        original = TkPhotoImage.new(file: path)
        scale = [original.width, original.height].max.fdiv(PICTURE_SIZE).ceil
        return original if scale <= 1
 
        small = TkPhotoImage.new
        small.copy(original, '-subsample', scale, scale)
        small
    end
 
    # actions

    # picks an image file and saves it as the profile picture
    def choose_picture
        path = Tk.getOpenFile
        return if path.to_s.empty?
 
        ok, msg = @app.set_profile_picture(@app.current_user, path)
        if ok
            show_picture
        else
            Tk.messageBox(type: 'ok', icon: 'error', title: 'Invalid Picture', message: msg)
        end
    end
 
    # clears the profile picture
    def remove_picture
        @app.remove_profile_picture(@app.current_user)
        show_picture
    end
 
    # saves the profile form
    def save_profile
        values = @entries.transform_values { |entry| entry.value.strip }
        ok, msg = @app.update_profile(**values)

        Tk.messageBox(type: 'ok', icon: ok ? 'info' : 'error',
                      title: ok ? 'Success' : 'Validation Error', message: msg)
    end

    # returns to the right dashboard
    def go_back
        @app.switch_to(@app.admin? ? AdminDashboardView : UserDashboardView)
    end
end
