require 'tk'

class AdminDashboardView < TkFrame
    TITLE_FONT   = 'Helvetica 16 bold'.freeze
    SECTION_FONT = 'Helvetica 12 bold'.freeze
    REPORT_FONT  = 'Courier 10'.freeze   # monospace so report columns line up
    NO_DATA      = '(none yet)'.freeze

    # Column layouts for the reports (printf-style)
    MASTER_ROW   = '%-4s %-15s %-30s %6s'.freeze
    # TODO (reports): add row formats for the new reports here, e.g.
    #   DETAIL_POST_ROW = '...'.freeze
    #   POST_ROW        = '...'.freeze

    def initialize(parent, app)
        super(parent)
        @app = app
        build_admin_ui
    end

    def build_admin_ui
        build_header
        build_stats
        build_recent_activity
        build_report_area
        show_report(:master)
    end

    private

    #layout

    def build_header
        header = TkFrame.new(self).pack(fill: 'x', pady: 10)
        TkLabel.new(header, text: 'Administrator Dashboard', font: TITLE_FONT).pack(side: 'left', padx: 10)
        TkButton.new(header, text: 'Logout', command: proc { @app.logout }).pack(side: 'right', padx: 10)
    end

    def build_stats
        s = @app.stats
        TkLabel.new(self, text: "Total Users: #{s[:users]}  |  Total Posts: #{s[:posts]}  |  " \
                    "Total Attachments: #{s[:attachments]}").pack(pady: 5)
                    "Total Deleted Accounts: #{s[:deleted_accounts]}").pack(pady: 5)
    end

    # builds the recently registered users and recently created posts panels
    def build_recent_activity
        row = TkFrame.new(self).pack(fill: 'x', padx: 10, pady: 5)
        recent_panel(row, 'Recently Registered Users', recent_user_lines)
        recent_panel(row, 'Recently Created Posts',    recent_post_lines)
    end

    # builds one titled box with left-aligned lines of text
    def recent_panel(parent, heading, lines)
        box = TkFrame.new(parent, relief: 'groove', borderwidth: 2)
        box.pack(side: 'left', fill: 'both', expand: true, padx: 5)
        TkLabel.new(box, text: heading, font: SECTION_FONT).pack(pady: 3)
        TkLabel.new(box, text: lines.join("\n"), justify: 'left', anchor: 'w').pack(fill: 'x', padx: 8, pady: 3)
    end

    # text lines for the newest users
    def recent_user_lines
        users = @app.recent_users
        return [NO_DATA] if users.empty?

        users.map { |u| "##{u[:id]}  #{truncate(u[:username], 15)}  #{truncate(u[:email], 25)}" }
    end

    # text lines for the newest posts
    def recent_post_lines
        posts = @app.recent_posts
        return [NO_DATA] if posts.empty?

        posts.map do |p|
            "##{p[:id]}  #{truncate(p[:title], 20)}  #{truncate(p[:author], 12)}  #{p[:created_at].strftime('%m/%d/%Y')}"
        end
    end

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
    def build_user_picker
        @user_picker_frame = TkFrame.new(self).pack(pady: 5)
    end

    #reports

    #makes it read-only.
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

# MASTER REPORT
# TODO (reports): still needed to match the requirements —
#   * Header line: "Date: <Time.now.strftime('%A, %B %-d, %Y')>    Admin: <@app.current_user[:username]>"
#   * Use u[:id] for User ID instead of i + 1
#   * Add an Address column (example shows "street, state": u[:address][:street], u[:address][:state])
#   * Footer caption: "Summary of all registered users"
def master_report
    users = @app.regular_users
    lines = [' MASTER REPORT ',
             format(MASTER_ROW, 'ID', 'Username', 'Email', 'Posts'),
             '-' * 58]
    users.each_with_index do |u, i|
        lines << format(MASTER_ROW, i + 1, truncate(u[:username], 15), truncate(u[:email], 30), u[:posts].length)
    end
    lines << NO_DATA if users.empty?
    lines.join("\n")
end

#USER DETAIL REPORT
# TODO (reports): build this report.
#   Data:  the user chosen in build_user_picker (or @app.find_user_by_id(id))
#   Header: User ID, Username, Email, Address (Street / City / State from user[:address])
#   Table:  Post ID, Title, Created Date, Updated Date — from user[:posts]
#           dates: post[:created_at].strftime('%m/%d/%Y')
#   Footer: "Number of Posts: N"
#   Return the whole report as one string (lines.join("\n")), like master_report.
def user_detail_report
    " USER DETAIL REPORT \n(not built yet)"
end

#POST REPORT
# TODO (reports): build this report.
#   Data:   @app.all_posts (already in Post ID order)
#   Table:  Post ID, Title, Created Date, Updated Date, Attachments, #
#           Attachments = names joined with ", " or "-" if none
#   Footer: "Total Number of Attachments: #{@app.total_attachments}"
#   Return the whole report as one string, like master_report.
def post_report
    " POST REPORT \n(not built yet)"
end

#Keeps long values from breaking the column layout.
def truncate(text, width)
    s = text.to_s
    s.length > width ? "#{s[0, width - 3]}..." : s
end
end
