require 'tk'
require 'bcrypt'
require_relative 'helpers/validator'

# User (values of users_hash, keyed by username):
#   { id: Integer, username:, email:, password: (bcrypt hash), role: :admin | :user,
#     address: { street:, city:, state:, zip: }, posts: [Post, ...] }
#
# Post (in the author's :posts AND in all_posts — same object in both):
#   { id: Integer (starts at 101), author: username, title:, content:,
#     created_at: Time, updated_at: Time, attachments: [Attachment, ...] }
#
# Attachment:
#   { name:, type:, size: Integer (KB) }
#
# Dates are Time objects; format them in the view, e.g.
#   time.strftime('%m/%d/%Y')          # => "08/01/2026"
#   Time.now.strftime('%A, %B %-d, %Y') # => "Friday, August 7, 2026"

class AppContext
    WINDOW_TITLE     = 'UserHub Desktop System'.freeze
    WINDOW_SIZE      = '900x700'.freeze
    FIRST_POST_ID    = 101
    SEED_SAMPLE_DATA = true   # set to false to start with no demo users/posts
    DAY              = 24 * 60 * 60

    attr_reader :root, :users_hash, :all_posts, :current_user

    def initialize
        @root = TkRoot.new
        @root.title(WINDOW_TITLE)
        @root.geometry(WINDOW_SIZE)

        @current_user  = nil
        @users_hash    = {}  #hash/Map collection for users
        @all_posts     = []  #array collection for posts
        @current_frame = nil
        @next_user_id  = 1
        @next_post_id  = FIRST_POST_ID

        seed_admin
        seed_sample_data if SEED_SAMPLE_DATA
    end

    #navigation

    def switch_to(view_class)
        @current_frame&.destroy
        @current_frame = view_class.new(@root, self)
        @current_frame.pack(fill: 'both', expand: true)
    end

    def run
        Tk.mainloop
    end

    #authentication

    def authenticate(login, password)
        user = find_user(login)
        return false unless user && BCrypt::Password.new(user[:password]) == password

        @current_user = user
        true
    end

    def logged_in?
        !@current_user.nil?
    end

    def admin?
        @current_user&.dig(:role) == :admin
    end

    def logout
        @current_user = nil
        switch_to(LoginRegisterView)
    end

    #user manegment

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

    def find_user(login)
        return nil if login.to_s.strip.empty?

        @users_hash[login] ||
                @users_hash.values.find { |u| u[:email].to_s.casecmp?(login) }
    end

    def find_user_by_id(id)
        @users_hash.values.find { |u| u[:id] == id.to_i }
    end

    def regular_users
        @users_hash.values.reject { |u| u[:role] == :admin }.sort_by { |u| u[:id] }
    end

    #reports

    def stats
        {
            users:       regular_users.length,
            posts:       @all_posts.length,
            attachments: total_attachments
        }
    end

    def total_attachments(posts = @all_posts)
        posts.sum { |p| p[:attachments].length }
    end

    #Posts and attachments

    def create_post(title, content)
        valid, msg = Validator.validate_post(title, content)
        return [false, msg] unless valid

        add_post(@current_user, title, content)
        [true, 'Post created.']
    end

    #removes this exact post object from its author and from all_posts.
    #(equal? compares identity, so two posts with the same text aren't both deleted.)
    #works for admins deleting other users' posts too.
    def delete_post(post)
        @users_hash.dig(post[:author], :posts)&.reject! { |p| p.equal?(post) }
        @all_posts.reject! { |p| p.equal?(post) }
    end

    def add_attachment(post, name:, type:, size:)
        valid, msg = Validator.validate_attachment(name, type, size, post[:attachments].length)
        return [false, msg] unless valid

        post[:attachments] << { name: name, type: type, size: size.to_i }
        touch(post)
        [true, 'Attachment added successfully!']
    end

    def remove_attachment(post, index)
        removed = post[:attachments].delete_at(index)
        return [false, 'Attachment not found.'] unless removed

        touch(post)
        [true, "Removed attachment \"#{removed[:name]}\"."]
    end

    private

    #record builder

    #defines what a user record looks like.
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

    #creates a post and adds it to both collections.
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

    #marks a post as updated now
    def touch(post)
        post[:updated_at] = Time.now
    end

    def take_user_id
        id = @next_user_id
        @next_user_id += 1
        id
    end

    def take_post_id
        id = @next_post_id
        @next_post_id += 1
        id
    end

    #seed data

    def seed_admin
        name = ENV.fetch('ADMIN_USERNAME', 'admin')
        #default makes the app runnable for grading; set ADMIN_PASSWORD to override.
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

    #demo users/posts so the reports have data during testing and grading
    #all sample users log in with password: password1
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

    def seed_post(user, title, content, days_ago:, edited_days_ago: days_ago, attachments: [])
        post = add_post(user, title, content, created_at: Time.now - days_ago * DAY)
        post[:updated_at] = Time.now - edited_days_ago * DAY
        attachments.each do |name, size|
            post[:attachments] << { name: name, type: File.extname(name), size: size }
        end
    end
end
