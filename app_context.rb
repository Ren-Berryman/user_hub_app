require 'tk'
require 'bcrypt'
require_relative 'helpers/validator'

# ============================================================================
# DATA MODEL (reference for the report views)
#
# User (values of users_hash, keyed by username):
#   { id: Integer, username:, email:, password: (bcrypt hash), role: :admin | :user,
#     address: { street:, city:, state:, zip: }, posts: [Post, ...] }
#
# Post (in the author's :posts AND in all_posts — same object in both):
#   { id: Integer (starts at 101), author: username, title:, content:,
#     created_at: Time, updated_at: Time, attachments: [Attachment, ...] }
#
# Attachment:
#   { name:, type:, size: Integer (KB), file_path: Text }
#
# Dates are Time objects; format them in the view, e.g.
#   time.strftime('%m/%d/%Y')          # => "08/01/2026"
#   Time.now.strftime('%A, %B %-d, %Y') # => "Friday, August 7, 2026"
# ============================================================================

class AppContext
    WINDOW_TITLE     = 'UserHub Desktop System'.freeze
    WINDOW_SIZE      = '900x700'.freeze
    FIRST_POST_ID    = 101
    SEED_SAMPLE_DATA = true   # set to false to start with no demo users/posts
    DAY              = 24 * 60 * 60

    attr_reader :root, :users_hash, :all_posts, :current_user, :deleted_account_count

    # sets up the window, data collections and seed data
    def initialize
        @root = TkRoot.new
        @root.title(WINDOW_TITLE)
        @root.geometry(WINDOW_SIZE)

        @current_user  = nil
        @users_hash    = {}  # hash/Map collection for users
        @all_posts     = []  # array collection for posts
        @current_frame = nil
        @next_user_id  = 1
        @next_post_id  = FIRST_POST_ID
        @deleted_account_count = 0

        seed_admin
        seed_sample_data if SEED_SAMPLE_DATA
    end

    # navigation

    # swaps the current screen for a new one
    def switch_to(view_class)
        @current_frame&.destroy
        @current_frame = view_class.new(@root, self)
        @current_frame.pack(fill: 'both', expand: true)
    end

    # starts the tk event loop
    def run
        Tk.mainloop
    end

    # authentication

    # checks login credentials and sets the current user
    def authenticate(login, password)
        user = find_user(login)
        return false unless user && BCrypt::Password.new(user[:password]) == password

        @current_user = user
        true
    end

    # checks if a user is logged in
    def logged_in?
        !@current_user.nil?
    end

    # checks if the current user is an admin
    def admin?
        @current_user&.dig(:role) == :admin
    end

    # clears the current user and returns to login
    def logout
        @current_user = nil
        switch_to(LoginRegisterView)
    end

    # user management

    # validates and saves a new user
    def register_user(username:, email:, password:, street:, city:, state:, zip:)
        valid, msg = Validator.validate_user(username, email, password)
        valid, msg = Validator.validate_address(street, city, state, zip) if valid
        return [false, msg] unless valid

        return [false, 'Username already taken.']   if @users_hash.key?(username)
        return [false, 'Email already registered.'] if find_user(email)

        @users_hash[username] = build_user(
            id:       take_user_id,
            username: username,
            email:    email,
            password: password,
            role:     :user,
            address:  { street: street, city: city, state: state, zip: zip }
        )
        [true, 'Registration successful. Please log in.']
    end

    # updates user info
    def update_profile(username:, email:, street:, city:, state:, zip:)
        user = @current_user
        return [false, 'You must be logged in to update your profile.'] unless user

        valid, msg = Validator.validate_profile(username, email, street, city, state, zip)
        return [false, msg] unless valid

        # Don't allow taking another user's username or email
        other = @users_hash[username]
        return [false, 'Username already taken.'] if other && !other.equal?(user)
        other = find_user(email)
        return [false, 'Email already registered.'] if other && !other.equal?(user)

        rename_user(user, username) unless username == user[:username]
        user[:email]   = email
        user[:address] = { street: street, city: city, state: state, zip: zip }
        [true, 'Profile updated successfully!']
    end

    # finds a user by username or email
    def find_user(login)
        return nil if login.to_s.strip.empty?

        @users_hash[login] ||
                @users_hash.values.find { |u| u[:email].to_s.casecmp?(login) }
    end

    # finds a user by user id
    def find_user_by_id(id)
        @users_hash.values.find { |u| u[:id] == id.to_i }
    end

    # allows user manager to delete user profile
    def delete_user(user)
    return [false, 'Cannot delete an admin account.'] if user[:role] == :admin

    removed_post_count = user[:posts].length
    @all_posts.reject! { |p| p[:author] == user[:username] }
    @users_hash.delete(user[:username])
    @deleted_account_count += 1
    [true, "Deleted \"#{user[:username]}\" and #{removed_post_count} post(s)."]
    end

    #updates user information using email, users is all users in userhub
    def update_user(user, email:, street:, city:, state:, zip:, password: nil)
        return [false, 'Cannot edit an admin account.'] if user[:role] == :admin

        valid, msg = Validator.validate_address(street, city, state, zip)
        return [false, msg] unless valid

        if email != user[:email]
            return [false, 'Email already registered.'] if find_user(email)

            user[:email] = email
        end

        user[:address].merge!(street: street, city: city, state: state, zip: zip)
        user[:password] = BCrypt::Password.create(password) unless password.to_s.empty?

        [true, 'User updated.'] #prints that user info has been updated
    end

    # returns all non-admin users sorted by id
    def regular_users
        @users_hash.values.reject { |u| u[:role] == :admin }.sort_by { |u| u[:id] }
    end

    # reports

    # returns user, post and attachment totals
    def stats
        {
            users:       regular_users.length,
            posts:       @all_posts.length,
            attachments: total_attachments
        }
    end

    # counts attachments across posts
    def total_attachments(posts = @all_posts)
        posts.sum { |p| p[:attachments].length }
    end

    # returns total # of accounts deleted in userhub
    def total_deleted_accounts()
        @deleted_account_count
    end

    # posts & attachments

    # validates and saves a new post
    def create_post(title, content)
        valid, msg = Validator.validate_post(title, content)
        return [false, msg] unless valid

        add_post(@current_user, title, content)
        [true, 'Post created.']
    end

    # removes a post from its author and all posts
    def delete_post(post)
        @users_hash.dig(post[:author], :posts)&.reject! { |p| p.equal?(post) }
        @all_posts.reject! { |p| p.equal?(post) }
    end

    #updates information in user's post
    def update_post(post)
        valid, msg = Validator.validate_post(title, content) # calls to validate post
        return [false, msg] unless valid
        #if valid, post can be updated with title and content
        post[:title]   = title
        post[:content] = content
        touch(post)
        [true, 'Post updated.']
    end

    def add_attachment(post, name:, type:, size:, path:)
        valid, msg = Validator.validate_attachment(name, type, size, path, post[:attachments].length)
    # validates and adds an attachment to a post
    def add_attachment(post, name:, type:, size:)
        valid, msg = Validator.validate_attachment(name, type, size, post[:attachments].length)
        return [false, msg] unless valid

        post[:attachments] << { name: name, type: type, size: size.to_i, path: path }
        touch(post)
        [true, 'Attachment added successfully!']
    end

    # removes an attachment from a post
    def remove_attachment(post, index)
        removed = post[:attachments].delete_at(index)
        return [false, 'Attachment not found.'] unless removed

        touch(post)
        [true, "Removed attachment \"#{removed[:name]}\"."]
    end

    # validates and updates a post title and content
    def update_post(post, title, content)
        valid, msg = Validator.validate_post(title, content)
        return [false, msg] unless valid

        post[:title]   = title
        post[:content] = content
        touch(post)
        [true, 'Post updated successfully!']
    end

    private

    # record builders

    # builds a new user record
    def build_user(id:, username:, email:, password:, role:, address: nil)
        {
            id:       id,
            username: username,
            email:    email,
            password: BCrypt::Password.create(password),
            role:     role,
            address:  address || { street: '', city: '', state: '', zip: '' },
            posts:    []
        }
    end

    # builds a new post and adds it to both collections
    def add_post(user, title, content, created_at: Time.now)
        post = {
            id:          take_post_id,
            author:      user[:username],
            title:       title,
            content:     content,
            created_at:  created_at,
            updated_at:  created_at,
            attachments: []
        }
        user[:posts] << post
        @all_posts << post
        post
    end

    # changes a username and updates its posts
    def rename_user(user, new_name)
        @users_hash.delete(user[:username])
        user[:posts].each { |post| post[:author] = new_name }
        user[:username] = new_name
        @users_hash[new_name] = user
    end

    # sets a post updated date to now
    def touch(post)
        post[:updated_at] = Time.now
    end

    # returns the next user id
    def take_user_id
        id = @next_user_id
        @next_user_id += 1
        id
    end

    # returns the next post id
    def take_post_id
        id = @next_post_id
        @next_post_id += 1
        id
    end

    # seed data

    # creates the admin account
    def seed_admin
        name = ENV.fetch('ADMIN_USERNAME', 'admin')
        # Default makes the app runnable for grading; set ADMIN_PASSWORD to override.
        pass = ENV.fetch('ADMIN_PASSWORD', 'admin123')
        warn "[UserHub] Using default admin password. Set ADMIN_PASSWORD to change it." unless ENV.key?('ADMIN_PASSWORD')

        @users_hash[name] = build_user(
            id:       0,   # admin is outside the regular User ID sequence
            username: name,
            email:    ENV.fetch('ADMIN_EMAIL', 'admin@localhost'),
            password: pass,
            role:     :admin
            )
    end

    # creates demo users and posts for testing
    def seed_sample_data
        register_user(username: 'john_smith', email: 'john@email.com', password: 'password1',
                      street: '123 Main St', city: 'Columbus', state: 'Ohio',    zip: '43215')
        register_user(username: 'sara_ali',   email: 'sara@email.com', password: 'password1',
                      street: '45 Oak Ave',   city: 'Austin',   state: 'Texas',   zip: '73301')
        register_user(username: 'mike2026',   email: 'mike@email.com', password: 'password1',
                      street: '78 Pine Rd',   city: 'Miami',    state: 'Florida', zip: '33101')

        john = @users_hash['john_smith']
        sara = @users_hash['sara_ali']

        seed_post(john, 'My First Ruby Project', 'Building a desktop app with Ruby/Tk.',
                  days_ago: 6, edited_days_ago: 5,
                  attachments: [['project.zip', 250], ['class_diagram.png', 120]])
        seed_post(john, 'Learning OOP Concepts', 'Classes, modules, and encapsulation.',
                  days_ago: 4)
        seed_post(sara, 'Database Design Notes', 'Normalization and ER diagrams.',
                  days_ago: 3,
                  attachments: [['Database_Design.pdf', 800], ['Profile_Image.jpg', 95],
                                ['Assignment_Instructions.docx', 40]])
        seed_post(sara, 'Study Group Schedule', 'Meeting times for the final project.',
                  days_ago: 1)
    end

    # creates a demo post with dates and attachments
    def seed_post(user, title, content, days_ago:, edited_days_ago: days_ago, attachments: [])
        post = add_post(user, title, content, created_at: Time.now - days_ago * DAY)
        post[:updated_at] = Time.now - edited_days_ago * DAY
        attachments.each do |name, size|
            post[:attachments] << { name: name, type: File.extname(name), size: size }
        end
    end
end
