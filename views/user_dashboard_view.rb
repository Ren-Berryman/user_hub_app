require 'tk'

class UserDashboardView < TkFrame
    HEADER_FONT  = 'Helvetica 14 bold'.freeze
    SECTION_FONT = 'Helvetica 12 bold'.freeze
    SUB_FONT     = 'Helvetica 10 bold'.freeze
    NO_SELECTION = 'Select a post above to manage attachments.'.freeze

    ATTACHMENT_FIELDS = [
        [:name, 'File Name:'],
        [:type, 'File Type (e.g. .pdf):'],
        [:size, 'File Size (KB):']
    ].freeze

    def initialize(parent, app)
        super(parent)
        @app  = app
        @user = app.current_user
        build_dashboard
    end

    def build_dashboard
        build_header
        build_post_list
        build_attachment_section
        refresh_posts
    end

    private

    #layout

    def build_header
        header = TkFrame.new(self).pack(fill: 'x', pady: 10)
        TkLabel.new(header, text: "Welcome, #{@user[:username]}!", font: HEADER_FONT).pack(side: 'left', padx: 10)
        @post_count_label = TkLabel.new(header).pack(side: 'left', padx: 10)
        TkButton.new(header, text: 'Logout', command: proc { @app.logout }).pack(side: 'right', padx: 10)
    end

    def build_post_list
        TkLabel.new(self, text: 'Your Posts', font: SECTION_FONT).pack(pady: 5)

        # exportselection: false keeps the post selected when you click into the entry fields below
        @post_listbox = TkListbox.new(self, height: 6, exportselection: false).pack(fill: 'x', padx: 20)
        @post_listbox.bind('<ListboxSelect>') { show_attachments }

        row = TkFrame.new(self).pack(pady: 5)
        TkButton.new(row, text: 'Create New Post',      command: proc { show_post_form }).pack(side: 'left', padx: 5)
        TkButton.new(row, text: 'Edit Selected Post',   command: proc { edit_selected_post }).pack(side: 'left', padx: 5)
        TkButton.new(row, text: 'Delete Selected Post', command: proc { delete_selected_post }).pack(side: 'left', padx: 5)
    end

    def build_attachment_section
        TkLabel.new(self, text: '--- Attachments for Selected Post ---', font: SUB_FONT).pack(pady: 10)
        @attach_label = TkLabel.new(self, text: NO_SELECTION).pack
        @attach_listbox = TkListbox.new(self, height: 4, exportselection: false).pack(fill: 'x', padx: 20)

        form = TkFrame.new(self).pack(pady: 5)
        @attach_entries = {}
        ATTACHMENT_FIELDS.each_with_index do |(key, label), row|
            TkLabel.new(form, text: label).grid(row: row, column: 0, sticky: 'e', padx: 5)
            entry = TkEntry.new(form)
            entry.grid(row: row, column: 1, pady: 2)
            @attach_entries[key] = entry
        end

        btn_row = TkFrame.new(self).pack(pady: 5)
        TkButton.new(btn_row, text: 'Add Attachment',             command: proc { add_attachment }).pack(side: 'left', padx: 5)
        TkButton.new(btn_row, text: 'Remove Selected Attachment', command: proc { remove_attachment }).pack(side: 'left', padx: 5)

        @status_msg = TkLabel.new(self).pack
    end

    #display

    def selected_index
        @post_listbox.curselection.first
    end

    def selected_post
        idx = selected_index
        idx && @user[:posts][idx]
    end

    #redraws the list and post count (optionally re-selects a row)
    def refresh_posts(select: nil)
        @post_listbox.clear
        @user[:posts].each_with_index do |post, idx|
            @post_listbox.insert('end', "##{idx + 1} | #{post[:title]} - Attachments: #{post[:attachments].length}")
        end
        @post_count_label.text = "Total Posts: #{@user[:posts].length}"
        @post_listbox.selection_set(select) if select
        show_attachments
    end

    def show_attachments
        post = selected_post
        @attach_listbox.clear
        return @attach_label.text = NO_SELECTION unless post

        @attach_label.text =
                if post[:attachments].empty?
        "\"#{post[:title]}\" has no attachments yet."
    else
        "Attachments for \"#{post[:title]}\" (select one to remove):"
    end
    post[:attachments].each do |a|
        @attach_listbox.insert('end', "#{a[:name]} (#{a[:type]}, #{a[:size]} KB)")
    end
end

def show_status(msg, ok)
    @status_msg.foreground = ok ? 'dark green' : 'red'
    @status_msg.text = msg
end

#actions

def show_post_form
    top = TkToplevel.new(self)
    top.title('New Post')

    TkLabel.new(top, text: 'Title:').pack(anchor: 'w', padx: 10)
    title_entry = TkEntry.new(top, width: 40).pack(padx: 10)
    TkLabel.new(top, text: 'Content:').pack(anchor: 'w', padx: 10)
    content_text = TkText.new(top, width: 40, height: 8, wrap: 'word').pack(padx: 10)
    err_label = TkLabel.new(top, foreground: 'red').pack

    save = proc do
        ok, msg = @app.create_post(title_entry.value.strip, content_text.get('1.0', 'end').strip)
        if ok
            top.destroy
            refresh_posts(select: @user[:posts].length - 1)
            show_status(msg, true)
        else
            err_label.text = msg
        end
    end

    TkButton.new(top, text: 'Save', command: save).pack(pady: 5)
    title_entry.focus
end

def delete_selected_post
    post = selected_post
    return show_status('Please select a post to delete.', false) unless post

    answer = Tk.messageBox(type: 'yesno', icon: 'question', title: 'Delete Post',
                           message: "Delete \"#{post[:title]}\"?")
    return unless answer == 'yes'

    @app.delete_post(post)
    refresh_posts
    show_status('Post deleted.', true)
end

# edit user-selected post in post list
def edit_selected_post
    post = selected_post
    return show_status('Please select a post to edit.', false) unless post

    show_post_form(post)
end

def add_attachment
    idx = selected_index
    return show_status('Please select a post first.', false) unless idx

    values = @attach_entries.transform_values { |entry| entry.value.strip }
    ok, msg = @app.add_attachment(@user[:posts][idx], **values)
    show_status(msg, ok)
    return unless ok

    @attach_entries.each_value { |entry| entry.value = '' }
    refresh_posts(select: idx)
end

def remove_attachment
    idx = selected_index
    return show_status('Please select a post first.', false) unless idx

    attach_idx = @attach_listbox.curselection.first
    return show_status('Please select an attachment to remove.', false) unless attach_idx

    ok, msg = @app.remove_attachment(@user[:posts][idx], attach_idx)
    show_status(msg, ok)
    refresh_posts(select: idx)
end
end
