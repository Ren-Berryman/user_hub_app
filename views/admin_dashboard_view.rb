require 'tk'

class AdminDashboardView < TkFrame
    TITLE_FONT   = 'Helvetica 16 bold'.freeze
    SECTION_FONT = 'Helvetica 12 bold'.freeze
    REPORT_FONT  = 'Courier 10'.freeze   # monospace so report columns line up
    NO_DATA      = '(none yet)'.freeze

    # Column layouts for the reports (printf-style)
    MASTER_ROW   = '%-4s %-15s %-30s %6s'.freeze
    POST_ROW     = '%-7s %-20s %-10s %-10s %-30s %3s'.freeze
    # TODO (reports): add row formats for the new reports here, e.g.
    #   DETAIL_POST_ROW = '...'.freeze

    # sets up the admin view
    def initialize(parent, app)
        super(parent)
        @app = app
        build_admin_ui
    end

    # builds all admin dashboard sections
    def build_admin_ui
        build_header
        build_stats
        build_report_area
        show_report(:master)
    end

    private

    # layout

    # builds the title bar and logout button
    def build_header
        header = TkFrame.new(self).pack(fill: 'x', pady: 10)
        TkLabel.new(header, text: 'Administrator Dashboard', font: TITLE_FONT).pack(side: 'left', padx: 10)
        TkButton.new(header, text: 'Logout', command: proc { @app.logout }).pack(side: 'right', padx: 10)
    end

    # builds the totals bar
    def build_stats
        s = @app.stats
        TkLabel.new(self, text: "Total Users: #{s[:users]}  |  Total Posts: #{s[:posts]}  |  " \
                    "Total Attachments: #{s[:attachments]}").pack(pady: 5)
    end

    # builds the report buttons and report box
    def build_report_area
        TkLabel.new(self, text: 'Administrator Reports', font: SECTION_FONT).pack(pady: 5)

        tabs = TkFrame.new(self).pack(pady: 5)
        TkButton.new(tabs, text: 'Master Report',      command: proc { show_report(:master) }).pack(side: 'left', padx: 5)
        TkButton.new(tabs, text: 'User Detail Report', command: proc { show_report(:user_detail) }).pack(side: 'left', padx: 5)
        TkButton.new(tabs, text: 'Post Report',        command: proc { show_report(:post) }).pack(side: 'left', padx: 5)

        build_user_picker

        box = TkFrame.new(self).pack(fill: 'both', expand: true, padx: 10, pady: 5)
        @report_text = TkText.new(box, height: 15, width: 90, font: REPORT_FONT, wrap: 'none')
        scrollbar = TkScrollbar.new(box, orient: 'vertical')
        @report_text.yscrollbar(scrollbar)
        scrollbar.pack(side: 'right', fill: 'y')
        @report_text.pack(side: 'left', fill: 'both', expand: true)
        # TODO (reports): if Post Report rows run wider than the box, add a horizontal
        # scrollbar here the same way: TkScrollbar with orient: 'horizontal' + @report_text.xscrollbar(...)
    end

    # TODO (reports): User Detail Report needs a way to choose a user.
    # Build it here (e.g. a TkListbox or dropdown of @app.regular_users).
    # When a user is selected, store it (e.g. @selected_user) and call show_report(:user_detail).
    # This area sits between the report buttons and the report box.
    # builds the user picker for the user detail report
    def build_user_picker
        @user_picker_frame = TkFrame.new(self).pack(pady: 5)
    end

    # reports

    # shows the chosen report in the report box
    def show_report(kind)
        content =
                case kind
    when :user_detail then user_detail_report
    when :post        then post_report
    else                   master_report
    end
    @report_text.configure(state: 'normal')
    @report_text.delete('1.0', 'end')
    @report_text.insert('1.0', content)
    @report_text.configure(state: 'disabled')
end

# master report

# TODO (reports): still needed to match the requirements —
#   * Header line: "Date: <Time.now.strftime('%A, %B %-d, %Y')>    Admin: <@app.current_user[:username]>"
#   * Use u[:id] for User ID instead of i + 1
#   * Add an Address column (example shows "street, state": u[:address][:street], u[:address][:state])
#   * Footer caption: "Summary of all registered users"
# builds the master report text
def master_report
    users = @app.regular_users
    lines = ['MASTER REPORT',
             format(MASTER_ROW, 'ID', 'Username', 'Email', 'Posts'),
             '-' * 58]
    users.each_with_index do |u, i|
        lines << format(MASTER_ROW, i + 1, truncate(u[:username], 15), truncate(u[:email], 30), u[:posts].length)
    end
    lines << NO_DATA if users.empty?
    lines.join("\n")
end

# user detail report

# TODO (reports): build this report.
#   Data:  the user chosen in build_user_picker (or @app.find_user_by_id(id))
#   Header: User ID, Username, Email, Address (Street / City / State from user[:address])
#   Table:  Post ID, Title, Created Date, Updated Date — from user[:posts]
#           dates: post[:created_at].strftime('%m/%d/%Y')
#   Footer: "Number of Posts: N"
#   Return the whole report as one string (lines.join("\n")), like master_report.
# builds the user detail report text
def user_detail_report
    "USER DETAIL REPORT \n(not built yet)"
end

# post report

# TODO (reports): build this report.
#   Data:   @app.all_posts (already in Post ID order)
#   Table:  Post ID, Title, Created Date, Updated Date, Attachments, #
#           Attachments = names joined with ", " or "-" if none
#   Footer: "Total Number of Attachments: #{@app.total_attachments}"
#   Return the whole report as one string, like master_report.
# builds the post report text
def post_report
    posts = @app.all_posts
    rule  = '-' * 85
    lines = ['POST REPORT',
             format(POST_ROW, 'Post ID', 'Title', 'Created', 'Updated', 'Attachments', '#'),
             rule]

    posts.each do |post|
        names = post[:attachments].map { |a| a[:name] }.join(', ')
        names = '-' if names.empty?

        lines << format(POST_ROW, post[:id], truncate(post[:title], 20),
                        post[:created_at].strftime('%m/%d/%Y'),
                        post[:updated_at].strftime('%m/%d/%Y'),
                        truncate(names, 30), post[:attachments].length)
    end

    lines << NO_DATA if posts.empty?
    lines << rule
    lines << "Total Number of Attachments: #{@app.total_attachments}"
    lines.join("\n")
end

# shortens long text to fit a column
def truncate(text, width)
    s = text.to_s
    s.length > width ? "#{s[0, width - 3]}..." : s
end
end
